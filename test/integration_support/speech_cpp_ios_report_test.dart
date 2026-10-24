import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../integration_test/piper/piper_ios_report.dart';
import '../../integration_test/speech_cpp/speech_cpp_ios_report.dart';

const _mib = 1024 * 1024;

PiperSynthesisSample _sample({
  String label = 'long',
  int elapsedMs = 1000,
  int samples = 48000 * 10,
  int sampleRate = 48000,
  double rms = 0.1,
}) => PiperSynthesisSample(
  label: label,
  characters: 50,
  elapsed: Duration(milliseconds: elapsedMs),
  samples: samples,
  sampleRate: sampleRate,
  rms: rms,
);

PiperMemorySample _memory(String stage, {int? available, int rss = 100}) =>
    PiperMemorySample(
      stage: stage,
      availableBytes: available,
      maxRssBytes: rss,
    );

SpeechCppIosReport _report({
  bool completed = true,
  List<PiperMemorySample>? memory,
  List<PiperSynthesisSample>? sentences,
  String? failure,
}) => SpeechCppIosReport(
  startedAt: DateTime(2026, 10, 25, 9, 5, 7),
  operatingSystemVersion: 'iPadOS 26.6.2',
  variant: SpeechCppVariant.q8_0,
  completed: completed,
  memory: memory ?? [_memory('after_load', available: 900 * _mib)],
  sentences: sentences ?? [_sample(elapsedMs: 2000)],
  failure: failure,
);

void main() {
  group('SpeechCppVariant', () {
    test('pins each quantization to one file, size and SHA-256', () {
      expect(
        SpeechCppVariant.q4_k.fileName,
        'Irodori-TTS-866M-MF-v4.1-Q4_K.gguf',
      );
      expect(SpeechCppVariant.q4_k.bytes, 863926048);
      expect(
        SpeechCppVariant.q4_k.sha256,
        '1913bf74000a3300c703eb91c985a4e5c4d7a2bbeb0cc7fe07d1583c4fea9729',
      );
      expect(
        SpeechCppVariant.q8_0.fileName,
        'Irodori-TTS-866M-MF-v4.1-Q8_0.gguf',
      );
      expect(SpeechCppVariant.q8_0.bytes, 1207133984);
      expect(
        SpeechCppVariant.q8_0.sha256,
        '2d161b0bbcd74f906f6b07e03d031075f8ae916db1b8bd4daf16cb37b451086a',
      );
      expect(
        SpeechCppVariant.f16.fileName,
        'Irodori-TTS-866M-MF-v4.1-F16.gguf',
      );
      expect(SpeechCppVariant.f16.bytes, 1920321792);
      expect(
        SpeechCppVariant.f16.sha256,
        'e237dc3eefe469b8bba87872beacf12fb7fe00dbdf85767edca8ec04ab910d13',
      );
    });

    test('downloads from the pinned revision, not the moving branch', () {
      expect(
        SpeechCppVariant.f16.downloadUrl.toString(),
        'https://huggingface.co/sakasegawa/Irodori-TTS-v4.1-Small-MF-GGUF/'
        'resolve/9db7da1bec3d1069ef8e29732e0497be60c7b047/'
        'Irodori-TTS-866M-MF-v4.1-F16.gguf',
      );
    });

    test('is chosen by the value passed with --dart-define', () {
      expect(SpeechCppVariant.parse('q4_k'), SpeechCppVariant.q4_k);
      expect(SpeechCppVariant.parse('q8_0'), SpeechCppVariant.q8_0);
      expect(SpeechCppVariant.parse('f16'), SpeechCppVariant.f16);
    });

    test('an unknown value names the choices', () {
      expect(
        () => SpeechCppVariant.parse('q2_k'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('q2_k'), contains('q4_k'), contains('f16')),
          ),
        ),
      );
    });
  });

  group('verifyModelFile', () {
    late Directory dir;
    late File file;
    final content = utf8.encode('not really a gguf');

    setUp(() {
      dir = Directory.systemTemp.createTempSync('speech_cpp_model');
      file = File(p.join(dir.path, 'model.gguf'))..writeAsBytesSync(content);
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('a file of the pinned size and digest is kept', () async {
      await verifyModelFile(
        file,
        bytes: content.length,
        sha256: sha256.convert(content).toString(),
      );
      expect(file.existsSync(), isTrue);
    });

    test('a wrong digest deletes the file and fails', () async {
      await expectLater(
        verifyModelFile(file, bytes: content.length, sha256: '0' * 64),
        throwsA(
          isA<ModelMismatchException>().having(
            (e) => e.toString(),
            'message',
            contains('SHA-256'),
          ),
        ),
      );
      expect(file.existsSync(), isFalse);
    });

    test('a wrong size deletes the file without hashing it', () async {
      await expectLater(
        verifyModelFile(
          file,
          bytes: content.length + 1,
          sha256: sha256.convert(content).toString(),
        ),
        throwsA(
          isA<ModelMismatchException>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('${content.length}'),
              contains('${content.length + 1}'),
            ),
          ),
        ),
      );
      expect(file.existsSync(), isFalse);
    });

    test('matchesPinnedSize tells a complete file from a missing one', () {
      expect(matchesPinnedSize(file, content.length), isTrue);
      expect(matchesPinnedSize(file, content.length + 1), isFalse);
      expect(matchesPinnedSize(File(p.join(dir.path, 'absent')), 1), isFalse);
    });
  });

  group('SpeechCppVerdict', () {
    test('passes when every criterion holds', () {
      final verdict = _report().verdict;
      expect(verdict.completed, isTrue);
      expect(verdict.memoryHeadroom, isTrue);
      expect(verdict.speed, isTrue);
      expect(verdict.passed, isTrue);
    });

    test('headroom under 512 MiB fails the memory criterion only', () {
      final verdict = _report(
        memory: [
          _memory('after_load', available: 900 * _mib),
          _memory('after_long', available: 511 * _mib),
        ],
      ).verdict;
      expect(verdict.memoryHeadroom, isFalse);
      expect(verdict.completed, isTrue);
      expect(verdict.speed, isTrue);
      expect(verdict.passed, isFalse);
    });

    test('exactly 512 MiB of headroom passes', () {
      final verdict = _report(
        memory: [_memory('after_long', available: 512 * _mib)],
      ).verdict;
      expect(verdict.memoryHeadroom, isTrue);
    });

    test('no headroom reading cannot pass the memory criterion', () {
      final verdict = _report(memory: [_memory('after_load')]).verdict;
      expect(verdict.memoryHeadroom, isFalse);
      expect(verdict.passed, isFalse);
    });

    test(
      'a long sentence at real time or slower fails the speed criterion',
      () {
        final verdict = _report(
          sentences: [
            _sample(label: 'medium', elapsedMs: 100),
            _sample(label: 'long', elapsedMs: 10000),
          ],
        ).verdict;
        expect(verdict.speed, isFalse);
        expect(verdict.passed, isFalse);
      },
    );

    test('no long sentence cannot pass the speed criterion', () {
      final verdict = _report(
        sentences: [_sample(label: 'medium', elapsedMs: 100)],
      ).verdict;
      expect(verdict.speed, isFalse);
    });

    test('a run that did not complete fails', () {
      final verdict = _report(completed: false, failure: 'killed').verdict;
      expect(verdict.completed, isFalse);
      expect(verdict.passed, isFalse);
    });
  });

  group('SpeechCppIosReport', () {
    test('names the file by quantization and start time', () {
      expect(_report().fileName, 'speech_cpp_ios_q8_0_20261025_090507.json');
    });

    test('encodes as JSON with the variant, measurements and verdict', () {
      final report = SpeechCppIosReport(
        startedAt: DateTime(2026, 10, 25, 9, 5, 7),
        operatingSystemVersion: 'iPadOS 26.6.2',
        variant: SpeechCppVariant.q4_k,
        speechVersion: '0.8.11',
        load: const Duration(milliseconds: 1500),
        reference: _sample(label: 'reference', elapsedMs: 300),
        sentences: [_sample(elapsedMs: 2000)],
        consecutive: [_sample(label: 'medium', elapsedMs: 500)],
        cancel: const SpeechCppCancelCheck(
          delay: Duration(milliseconds: 250),
          cancelled: true,
          elapsed: Duration(milliseconds: 270),
          nextSynthesisSucceeded: true,
        ),
        memory: [_memory('after_load', available: 900 * _mib, rss: 200)],
        completed: true,
      );
      final json =
          jsonDecode(jsonEncode(report.toJson())) as Map<String, Object?>;

      expect(json['variant'], 'q4_k');
      expect(json['model_file'], 'Irodori-TTS-866M-MF-v4.1-Q4_K.gguf');
      expect(json['speech_version'], '0.8.11');
      expect(json['load_ms'], 1500);
      expect((json['reference'] as Map)['label'], 'reference');
      expect((json['sentences'] as List).single, isA<Map>());
      expect((json['consecutive'] as List).single, isA<Map>());
      expect(json['cancel'], {
        'delay_ms': 250,
        'cancelled': true,
        'elapsed_ms': 270,
        'next_synthesis_succeeded': true,
      });
      expect(json['min_available_bytes'], 900 * _mib);
      expect(json['peak_rss_bytes'], 200);
      expect(json['completed'], isTrue);
      expect(json['verdict'], {
        'completed': true,
        'memory_headroom': true,
        'speed': true,
        'passed': true,
        'min_headroom_bytes_required': 512 * _mib,
        'max_long_rtf': 1.0,
      });
      expect(json['failure'], isNull);
    });
  });
}
