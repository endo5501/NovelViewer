// On-device measurement of Irodori-TTS v4.1 Small MF on speech.cpp.
//
// Answers whether the model fits in the memory an iPad grants an app, and
// speaks fast enough, before speech.cpp is wired into the app. One
// quantization per run, chosen with --dart-define, because ProcessInfo.maxRss
// only grows: a second model in the same process would inherit the first
// one's peak. Run Q4_K, then Q8_0, then F16, so a run killed for memory does
// not cost the smaller ones. See openspec change speech-cpp-ios-spike, design
// D6-D9.
//
// The model runs on a worker isolate: speech_synthesize() blocks its caller,
// and this isolate has to stay free to read memory while it runs and to ask
// for a stop from another thread, as the app does: by writing a flag the
// worker's callbacks read, never by touching the request.
//
// Run with flutter drive (a device needs profile mode, see test_driver/):
//   device:
//     fvm flutter drive --profile --driver=test_driver/integration_test.dart \
//       --target=integration_test/speech_cpp_ios_test.dart \
//       --dart-define=SPEECH_CPP_VARIANT=q4_k -d <device UDID>
//   simulator (opens the framework only):
//     fvm flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/speech_cpp_ios_test.dart -d <simulator>
//
// Result: build/integration_response_data.json on the host, and on the device
// Documents/benchmarks/speech_cpp_ios_<variant>_<timestamp>.json with a WAV
// of the reference voice and of each sentence beside it. flutter drive
// uninstalls the app when a run ends, so the device copy survives only a run
// that jetsam killed; back up the app's data first (test_driver/).

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_download/data/novel_library_service.dart';
import 'package:novel_viewer/features/tts/data/model_download_utils.dart';
import 'package:novel_viewer/features/tts/data/speech_cpp_native_bindings.dart';
import 'package:novel_viewer/features/tts/data/wav_writer.dart';
import 'package:novel_viewer/features/tts/providers/tts_model_download_providers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'piper/piper_ios_report.dart';
import 'speech_cpp/speech_cpp_ios_report.dart';

const _variantName = String.fromEnvironment(
  'SPEECH_CPP_VARIANT',
  defaultValue: 'q4_k',
);

/// Spoken with no reference voice; its audio becomes the reference (D7).
const _referenceText = '今日はいい天気ですね。少し散歩に出かけてみようと思います。';

const _sentences = {
  // 51 characters: longer than the 45-character sentence that crashed
  // audio.cpp's v3 on this iPad.
  'medium': '彼は静かに扉を開けると薄暗い廊下の奥から聞こえてくるかすかな足音に耳を澄ませながらゆっくりと歩き出した',
  // 125 characters in one sentence, about 24 s of speech on macOS.
  'long':
      '彼は静かに扉を開けると薄暗い廊下の奥から聞こえてくるかすかな足音に耳を澄ませながらゆっくりと歩き出したが'
      'その足取りは重く胸の奥では言いようのない不安が渦巻いておりいつか見た夢の中の光景が何度も脳裏に'
      'よみがえってきてどうしても振り払うことができなかった',
};

const _consecutiveRuns = 10;
const _seed = 1;

/// How often memory is read while a stage runs. The stage's least headroom,
/// not the reading after it, is what jetsam acts on.
const _memoryPollInterval = Duration(milliseconds: 50);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'speech.cpp speaks Irodori-TTS within the iPad memory limit',
    (tester) async {
      final bindings = SpeechCppNativeBindings.open();
      final speechVersion = bindings.version().toDartString();
      // ignore: avoid_print
      print('speech.cpp $speechVersion at ${Platform.resolvedExecutable}');
      expect(speechVersion, isNotEmpty);
      if (isIosSimulatorExecutable(Platform.resolvedExecutable)) {
        // speech.cpp's Metal inference runs on devices only (D9).
        return;
      }

      final variant = SpeechCppVariant.parse(_variantName);
      final library = await NovelLibraryService().ensureLibraryDirectory();
      final container = ProviderContainer(
        overrides: [libraryPathProvider.overrideWithValue(library.path)],
      );
      addTearDown(container.dispose);
      final modelPath = p.join(
        container.read(modelsDirectoryPathProvider)!,
        'speech-cpp',
        'Irodori-TTS-v4.1-Small-MF',
        variant.fileName,
      );

      final documents = (await getApplicationDocumentsDirectory()).path;
      final startedAt = DateTime.now();
      final memory = <PiperMemorySample>[];
      final sentences = <PiperSynthesisSample>[];
      final consecutive = <PiperSynthesisSample>[];
      PiperSynthesisSample? reference;
      SpeechCppCancelCheck? cancel;
      Duration? load;
      var completed = false;

      final provisional = SpeechCppIosReport(
        startedAt: startedAt,
        operatingSystemVersion: '',
        variant: variant,
      );
      final benchmarks = p.join(documents, 'benchmarks');
      final stem = p.basenameWithoutExtension(provisional.fileName);

      // Rewrites the report with what has been measured so far, so a failure
      // — or jetsam killing the process — still leaves the earlier stages.
      String persist({String? failure}) {
        final report = SpeechCppIosReport(
          startedAt: startedAt,
          operatingSystemVersion: Platform.operatingSystemVersion,
          variant: variant,
          speechVersion: speechVersion,
          load: load,
          reference: reference,
          sentences: sentences,
          consecutive: consecutive,
          cancel: cancel,
          memory: memory,
          completed: completed,
          failure: failure,
        );
        final json = report.toJson();
        // Sent to the host by flutter drive's driver, even on failure.
        binding.reportData = {'speech_cpp_ios': json};
        final out = File(p.join(benchmarks, report.fileName));
        out.createSync(recursive: true);
        out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
        return out.path;
      }

      void sampleMemory(String stage, {int? available}) => memory.add(
        PiperMemorySample(
          stage: stage,
          availableBytes: available ?? _availableMemory(),
          maxRssBytes: ProcessInfo.maxRss,
        ),
      );

      // Runs [stage] while reading memory every [_memoryPollInterval], and
      // records the least headroom seen during it and the reading after it.
      Future<T> measured<T>(String stage, Future<T> Function() body) async {
        int? least;
        void poll() {
          final now = _availableMemory();
          if (now != null && (least == null || now < least!)) least = now;
        }

        poll();
        final timer = Timer.periodic(_memoryPollInterval, (_) => poll());
        try {
          return await body();
        } finally {
          timer.cancel();
          poll();
          sampleMemory('${stage}_least', available: least);
          sampleMemory('after_$stage');
          persist();
        }
      }

      final worker = await _SpeechWorker.spawn();
      try {
        await _ensureModel(modelPath, variant);

        sampleMemory('before_load');
        // Written before the native load: jetsam killing the process while
        // the model loads leaves no other record of the run.
        persist();
        final loadWatch = Stopwatch()..start();
        await measured('load', () => worker.load(modelPath));
        loadWatch.stop();
        load = loadWatch.elapsed;
        persist();

        PiperSynthesisSample sampleOf(
          String label,
          String text,
          _Synthesized result,
        ) {
          final sample = PiperSynthesisSample(
            label: label,
            characters: text.runes.length,
            elapsed: result.elapsed,
            samples: result.samples.length,
            sampleRate: result.sampleRate,
            rms: rootMeanSquare(result.samples),
          );
          expect(
            result.sampleRate,
            48000,
            reason: '"$label" is not at the model rate',
          );
          expect(sample.isSilent, isFalse, reason: '"$label" came out silent');
          return sample;
        }

        Future<void> saveWav(String label, _Synthesized result) =>
            WavWriter.write(
              path: p.join(benchmarks, '${stem}_$label.wav'),
              audio: result.samples,
              sampleRate: result.sampleRate,
            );

        final referenceResult = await measured(
          'reference',
          () => worker.synthesize(_referenceText, voice: 'none'),
        );
        reference = sampleOf('reference', _referenceText, referenceResult);
        final referencePath = p.join(benchmarks, '${stem}_reference.wav');
        await saveWav('reference', referenceResult);
        await measured(
          'add_voice',
          () => worker.addVoice('ref', referencePath),
        );

        for (final entry in _sentences.entries) {
          final result = await measured(
            entry.key,
            () => worker.synthesize(entry.value, voice: 'ref'),
          );
          sentences.add(sampleOf(entry.key, entry.value, result));
          await saveWav(entry.key, result);
          persist();
        }

        for (var i = 0; i < _consecutiveRuns; i++) {
          final text = _sentences['medium']!;
          final result = await measured(
            'consecutive_${i + 1}',
            () => worker.synthesize(text, voice: 'ref'),
          );
          consecutive.add(sampleOf('medium', text, result));
          persist();
        }

        // Stop the long sentence from this isolate, at half the time the
        // medium one takes, which lands inside the long one's synthesis.
        final mediumTime = sentences.firstWhere((s) => s.label == 'medium');
        final delay = mediumTime.elapsed ~/ 2;
        Future<void>? cancelSent;
        final _Synthesized cancelled;
        try {
          cancelled = await measured(
            'cancel',
            () => worker.synthesize(
              _sentences['long']!,
              voice: 'ref',
              onStarted: () =>
                  cancelSent = Future.delayed(delay, worker.requestStop),
            ),
          );
        } finally {
          // A stop that lands after the next synthesis began would stop that
          // one instead, so it is sent before going on.
          await cancelSent;
        }
        final after = await measured(
          'after_cancel',
          () => worker.synthesize(_sentences['medium']!, voice: 'ref'),
        );
        cancel = SpeechCppCancelCheck(
          delay: delay,
          cancelled: cancelled.cancelled,
          elapsed: cancelled.elapsed,
          nextSynthesisSucceeded: !after.cancelled && after.samples.isNotEmpty,
        );
        expect(
          cancelled.cancelled,
          isTrue,
          reason: 'the cancelled request ended with audio',
        );
        expect(cancel.nextSynthesisSucceeded, isTrue);

        completed = true;
      } catch (error) {
        // Must not replace the failure being reported if the write fails too.
        try {
          persist(failure: '$error');
        } catch (persistError) {
          // ignore: avoid_print
          print('Could not write the report: $persistError');
        }
        rethrow;
      } finally {
        await worker.close();
      }

      final path = persist();
      // Line by line: the device log truncates long lines.
      // ignore: avoid_print
      print('=== speech.cpp iOS measurement: $path ===');
      for (final line in File(path).readAsLinesSync()) {
        // ignore: avoid_print
        print(line);
      }
    },
    skip: !Platform.isIOS,
    timeout: Timeout.none,
  );
}

/// Downloads [variant] to [path] unless a matching file is there, then checks
/// its size and SHA-256 (design D6).
Future<void> _ensureModel(String path, SpeechCppVariant variant) async {
  final file = File(path);
  if (!matchesPinnedSize(file, variant.bytes)) {
    file.parent.createSync(recursive: true);
    final client = http.Client();
    try {
      await downloadFile(
        client,
        variant.downloadUrl.toString(),
        path,
        variant.fileName,
        null,
      );
    } finally {
      client.close();
    }
  }
  await verifyModelFile(file, bytes: variant.bytes, sha256: variant.sha256);
}

/// Bytes the process may still allocate before jetsam terminates it, from
/// `os_proc_available_memory` (iOS 13+). Null where the symbol is absent.
int? _availableMemory() => _osProcAvailableMemory?.call();

// Looked up once: memory is read every _memoryPollInterval.
final int Function()? _osProcAvailableMemory = () {
  final process = DynamicLibrary.process();
  if (!process.providesSymbol('os_proc_available_memory')) return null;
  return process.lookupFunction<Size Function(), int Function()>(
    'os_proc_available_memory',
  );
}();

/// What one synthesis on the worker returned.
class _Synthesized {
  const _Synthesized({
    required this.samples,
    required this.sampleRate,
    required this.elapsed,
    required this.cancelled,
  });

  final Float32List samples;
  final int sampleRate;
  final Duration elapsed;
  final bool cancelled;
}

/// A worker isolate holding one model, answering one command at a time.
class _SpeechWorker {
  _SpeechWorker._(
    this._isolate,
    this._commands,
    this._replies,
    this._stopFlag,
    this._exited,
  );

  /// Spawns the worker with a stop flag this isolate owns. The flag outlives
  /// every request, so writing it is safe at any time until [close] frees it
  /// after the worker has exited.
  static Future<_SpeechWorker> spawn() async {
    final stopFlag = calloc<Int32>();
    final replies = ReceivePort();
    final exited = ReceivePort();
    final isolate = await Isolate.spawn(_workerMain, [
      replies.sendPort,
      stopFlag.address,
    ], onExit: exited.sendPort);
    final events = StreamIterator(replies);
    await events.moveNext();
    return _SpeechWorker._(
      isolate,
      events.current as SendPort,
      events,
      stopFlag,
      exited,
    );
  }

  final Isolate _isolate;
  final SendPort _commands;
  final StreamIterator<dynamic> _replies;
  final Pointer<Int32> _stopFlag;
  final ReceivePort _exited;

  /// Asks the synthesis under way to stop, from this isolate.
  void requestStop() => _stopFlag.value = 1;

  Future<Object?> _next() async {
    await _replies.moveNext();
    final reply = _replies.current;
    if (reply is _WorkerError) throw StateError(reply.message);
    return reply;
  }

  Future<void> load(String path) async {
    _commands.send(['load', path]);
    await _next();
  }

  Future<void> addVoice(String name, String path) async {
    _commands.send(['voice', name, path]);
    await _next();
  }

  /// Speaks [text]. [onStarted] runs once the worker has cleared the stop flag
  /// and is about to synthesize.
  Future<_Synthesized> synthesize(
    String text, {
    required String voice,
    void Function()? onStarted,
  }) async {
    _commands.send(['synthesize', text, voice, _seed]);
    await _next();
    onStarted?.call();
    final reply = await _next() as List<Object?>;
    return _Synthesized(
      samples: (reply[0] as TransferableTypedData)
          .materialize()
          .asFloat32List(),
      sampleRate: reply[1] as int,
      elapsed: Duration(microseconds: reply[2] as int),
      cancelled: reply[3] as bool,
    );
  }

  /// Frees the model and stops the worker. A worker that died or stopped
  /// answering would otherwise hang the run here, in a finally, and hide the
  /// failure being reported.
  Future<void> close() async {
    try {
      _commands.send(['close']);
      await _next().timeout(const Duration(seconds: 30));
    } finally {
      final exited = _exited.first;
      _isolate.kill(priority: Isolate.immediate);
      await _replies.cancel();
      // The worker reads the flag, so it is freed only once the worker is
      // gone. A worker still inside native code after the timeout keeps it:
      // a small leak in a test process beats a write into freed memory.
      final gone = await exited
          .then((_) => true)
          .timeout(const Duration(seconds: 30), onTimeout: () => false);
      if (gone) calloc.free(_stopFlag);
      _exited.close();
    }
  }
}

class _WorkerError {
  const _WorkerError(this.message);
  final String message;
}

void _workerMain(List<Object> args) {
  final replies = args[0] as SendPort;
  final stopFlag = Pointer<Int32>.fromAddress(args[1] as int);
  final commands = ReceivePort();
  replies.send(commands.sendPort);
  final bindings = SpeechCppNativeBindings.open();
  SpeechCppModel? model;

  commands.listen((message) {
    final command = message as List<Object?>;
    try {
      switch (command[0]) {
        case 'load':
          model = SpeechCppModel.load(bindings, command[1] as String);
          replies.send(null);
        case 'voice':
          model!.addVoice(command[1] as String, command[2] as String);
          replies.send(null);
        case 'synthesize':
          final request = model!.newRequest(
            command[1] as String,
            strings: {'voice': command[2] as String},
            ints: {'seed': command[3] as int},
          );
          try {
            stopFlag.value = 0;
            replies.send(null);
            final watch = Stopwatch()..start();
            final outcome = request.synthesize(
              shouldStop: () => stopFlag.value != 0,
            );
            watch.stop();
            final samples = switch (outcome) {
              SpeechCppAudio(:final samples) => samples,
              SpeechCppCancelled() => Float32List(0),
            };
            replies.send([
              TransferableTypedData.fromList([samples]),
              model!.sampleRate,
              watch.elapsedMicroseconds,
              outcome is SpeechCppCancelled,
            ]);
          } finally {
            request.dispose();
          }
        case 'close':
          model?.dispose();
          model = null;
          replies.send(null);
          commands.close();
      }
    } catch (error) {
      replies.send(_WorkerError('$error'));
    }
  });
}
