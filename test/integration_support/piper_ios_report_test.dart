import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/piper/piper_ios_report.dart';

PiperSynthesisSample _sample({
  String label = 'medium',
  int characters = 40,
  int elapsedMs = 1000,
  int samples = 22050 * 4,
  int sampleRate = 22050,
  double rms = 0.1,
}) => PiperSynthesisSample(
  label: label,
  characters: characters,
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

void main() {
  group('rootMeanSquare', () {
    test('is zero for silence and for no audio', () {
      expect(rootMeanSquare(Float32List(100)), 0.0);
      expect(rootMeanSquare(Float32List(0)), 0.0);
    });

    test('is the amplitude of a constant signal', () {
      expect(
        rootMeanSquare(Float32List.fromList([0.5, -0.5, 0.5, -0.5])),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('PiperSynthesisSample', () {
    test('audio length is samples over sample rate', () {
      expect(_sample(samples: 22050 * 4).audioSeconds, 4.0);
    });

    test('RTF is synthesis time over audio length', () {
      expect(_sample(elapsedMs: 1000, samples: 22050 * 4).rtf, 0.25);
    });

    test('RTF is null when no audio was produced', () {
      expect(_sample(samples: 0).rtf, isNull);
    });

    test('RTF is null without a sample rate, so the report stays encodable', () {
      final sample = _sample(sampleRate: 0);
      expect(sample.rtf, isNull);
      expect(() => jsonEncode(sample.toJson()), returnsNormally);
    });

    test('audio below the silence threshold counts as silent', () {
      expect(_sample(rms: 0.0).isSilent, isTrue);
      expect(_sample(rms: silenceRmsThreshold / 2).isSilent, isTrue);
      expect(_sample(rms: 0.1).isSilent, isFalse);
    });

    test('no audio counts as silent whatever the RMS says', () {
      expect(_sample(samples: 0, rms: 0.1).isSilent, isTrue);
    });

    test('serialises every measured field', () {
      expect(
        _sample(
          label: 'kanji_only',
          characters: 3,
          elapsedMs: 500,
          samples: 22050,
          rms: 0.2,
        ).toJson(),
        {
          'label': 'kanji_only',
          'characters': 3,
          'synthesis_ms': 500,
          'audio_seconds': 1.0,
          'rtf': 0.5,
          'rms': 0.2,
        },
      );
    });
  });

  group('isJapanesePhonemization', () {
    test('accepts a non-empty result resolved as Japanese', () {
      expect(isJapanesePhonemization(language: 'ja', phonemeCount: 18), isTrue);
    });

    test(
      'rejects an empty result, which is what the unpatched build gives',
      () {
        expect(
          isJapanesePhonemization(language: 'ja', phonemeCount: 0),
          isFalse,
        );
      },
    );

    test('rejects a result resolved as another language', () {
      expect(
        isJapanesePhonemization(language: 'zh', phonemeCount: 12),
        isFalse,
      );
    });
  });

  group('PiperIosReport', () {
    final startedAt = DateTime(2026, 10, 17, 9, 5, 3);

    PiperIosReport report({
      List<PiperSynthesisSample> consecutive = const [],
      List<PiperMemorySample> memory = const [],
      String? failure,
    }) => PiperIosReport(
      startedAt: startedAt,
      operatingSystemVersion: 'Version 26.6.2',
      load: const Duration(milliseconds: 800),
      phonemization: const PiperPhonemization(
        text: 'こんにちは、世界。',
        language: 'ja',
        phonemeCount: 18,
        phonemes: 'k o N n i',
      ),
      sentences: [_sample(label: 'short')],
      consecutive: consecutive,
      memory: memory,
      failure: failure,
    );

    test('file name carries the start time', () {
      expect(report().fileName, 'piper_ios_20261017_090503.json');
    });

    test('mean consecutive RTF averages the runs that produced audio', () {
      final r = report(
        consecutive: [
          _sample(elapsedMs: 1000, samples: 22050 * 4),
          _sample(elapsedMs: 3000, samples: 22050 * 4),
          _sample(samples: 0),
        ],
      );
      expect(r.meanConsecutiveRtf, closeTo(0.5, 1e-9));
    });

    test('mean consecutive RTF is null before any run', () {
      expect(report().meanConsecutiveRtf, isNull);
    });

    test('headroom and peak memory come from the readings', () {
      final r = report(
        memory: [
          _memory('before_load', available: 3000, rss: 100),
          _memory('after_load', available: 2500, rss: 400),
          _memory('unknown', rss: 300),
        ],
      );
      expect(r.minAvailableBytes, 2500);
      expect(r.peakRssBytes, 400);
    });

    test('headroom is null when it could never be read', () {
      expect(report(memory: [_memory('x')]).minAvailableBytes, isNull);
    });

    test('serialises to JSON with every section', () {
      final json =
          jsonDecode(
                jsonEncode(
                  report(
                    consecutive: [_sample()],
                    memory: [_memory('after_load', available: 2500)],
                    failure: 'boom',
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>;
      expect(json['started_at'], startedAt.toIso8601String());
      expect(json['os'], 'Version 26.6.2');
      expect(json['load_ms'], 800);
      expect(json['phonemization'], {
        'text': 'こんにちは、世界。',
        'language': 'ja',
        'phoneme_count': 18,
        'phonemes': 'k o N n i',
      });
      expect(json['sentences'], hasLength(1));
      expect(json['consecutive'], hasLength(1));
      expect(json['mean_consecutive_rtf'], 0.25);
      expect(json['min_available_bytes'], 2500);
      expect(json['peak_rss_bytes'], 100);
      expect(json['memory'], [
        {'stage': 'after_load', 'available_bytes': 2500, 'max_rss_bytes': 100},
      ]);
      expect(json['failure'], 'boom');
    });
  });
}
