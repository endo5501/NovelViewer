// On-device check that Piper speaks Japanese on iOS.
//
// iOS builds of piper-plus need the project's patch (patches/piper-plus/) for
// OpenJTalk to run at all, so this checks the phonemizer itself as well as the
// audio. It then loads the model through the same TtsSession -> TtsIsolate path
// the app uses, synthesises the check sentences and the medium one repeatedly,
// and records timings and memory headroom. See openspec change piper-ios-build,
// design D6, for the criteria the measurements feed.
//
// The model and dictionary are taken from where the app keeps them
// (<library>/../models/piper) and downloaded there with the app's own
// downloader when missing.
//
// Run with flutter drive, which leaves the app and the downloaded model
// installed (flutter test uninstalls both):
//   simulator:
//     fvm flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/piper_ios_synthesis_test.dart -d <simulator>
//   device (needs profile mode, see test_driver/):
//     fvm flutter drive --profile --driver=test_driver/integration_test.dart \
//       --target=integration_test/piper_ios_synthesis_test.dart -d <device UDID>
//
// Result: build/integration_response_data.json on the host, and
// Documents/benchmarks/piper_ios_<timestamp>.json on the device.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:novel_viewer/features/text_download/data/novel_library_service.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/tts/data/piper_model_download_service.dart';
import 'package:novel_viewer/features/tts/data/piper_native_bindings.dart';
import 'package:novel_viewer/features/tts/data/tts_isolate.dart';
import 'package:novel_viewer/features/tts/data/tts_session.dart';
import 'package:novel_viewer/features/tts/domain/tts_engine_config.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'piper/piper_ios_report.dart';

const _phonemizeText = 'こんにちは、世界。';

const _sentences = {
  'short': 'こんにちは、世界。',
  // No kana: upstream would classify it as Chinese without the app's
  // zh-free config, and say nothing (piper-tts-native-engine).
  'kanji_only': '多分。',
  'medium': '駅前の小さな喫茶店で、彼女は窓の外を眺めながら、冷めかけたコーヒーをゆっくりと口に運んだ。',
  'long':
      '夜が明けるころ、村のはずれにある古い水車小屋から、かすかな歌声が聞こえてきた。'
      '誰が歌っているのかを確かめようと、少年は霜の降りた畦道を駆け出したが、'
      '小屋の扉を開けたときには、ただ回り続ける水車の音だけが、静かに響いていた。',
};

/// Number of back-to-back syntheses of the medium sentence (design D6).
const _consecutiveRuns = 10;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Piper phonemizes and speaks Japanese on iOS',
    (tester) async {
      // The app's defaults, not whatever an earlier run left in preferences.
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(
        await SharedPreferences.getInstance(),
      );

      final library = await NovelLibraryService().ensureLibraryDirectory();
      final piperDir = p.join(p.dirname(library.path), 'models', 'piper');
      final dicDir = p.join(piperDir, 'open_jtalk_dic');
      final modelName = settings.getPiperModelName();
      final modelPath = p.join(
        piperDir,
        PiperModelDownloadService.onnxFileName(modelName),
      );

      final documents = (await getApplicationDocumentsDirectory()).path;
      final startedAt = DateTime.now();
      final memory = <PiperMemorySample>[];
      final sentences = <PiperSynthesisSample>[];
      final consecutive = <PiperSynthesisSample>[];
      Duration? load;
      PiperPhonemization? phonemization;

      void sampleMemory(String stage) => memory.add(
        PiperMemorySample(
          stage: stage,
          availableBytes: _availableMemory(),
          maxRssBytes: ProcessInfo.maxRss,
        ),
      );

      // Rewrites the report with what has been measured so far, so a failure
      // — or jetsam killing the process — still leaves the earlier stages.
      String persist({String? failure}) {
        final report = PiperIosReport(
          startedAt: startedAt,
          operatingSystemVersion: Platform.operatingSystemVersion,
          load: load,
          phonemization: phonemization,
          sentences: sentences,
          consecutive: consecutive,
          memory: memory,
          failure: failure,
        );
        final json = report.toJson();
        // Sent to the host by flutter drive's driver, even on failure.
        binding.reportData = {'piper_ios': json};
        final out = File(p.join(documents, 'benchmarks', report.fileName));
        out.createSync(recursive: true);
        out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
        return out.path;
      }

      final session = TtsSession(isolate: TtsIsolate());
      try {
        await _ensureModelAndDictionary(piperDir, dicDir, modelName);

        // On the test's own isolate, straight through FFI: TtsSession does
        // not expose the phonemizer, and its result is the direct evidence
        // that OpenJTalk runs.
        phonemization = _phonemize(modelPath, dicDir, _phonemizeText);
        persist();
        expect(
          isJapanesePhonemization(
            language: phonemization.language,
            phonemeCount: phonemization.phonemeCount,
          ),
          isTrue,
          reason:
              'phonemizer returned ${phonemization.phonemeCount} phonemes '
              'as "${phonemization.language}" for $_phonemizeText',
        );

        sampleMemory('before_load');
        final loadWatch = Stopwatch()..start();
        final loaded = await session.ensureModelLoaded(
          PiperEngineConfig(
            modelDir: modelPath,
            sampleRate: 22050,
            dicDir: dicDir,
            lengthScale: settings.getPiperLengthScale(),
            noiseScale: settings.getPiperNoiseScale(),
            noiseW: settings.getPiperNoiseW(),
          ),
        );
        loadWatch.stop();
        expect(loaded, isTrue, reason: 'Piper model load failed');
        load = loadWatch.elapsed;
        sampleMemory('after_load');
        persist();

        Future<PiperSynthesisSample> synthesize(String label) async {
          final text = _sentences[label]!;
          final watch = Stopwatch()..start();
          final result = await session.synthesize(text: text);
          watch.stop();
          if (result == null || result.audio == null) {
            fail('synthesis of "$label" failed: ${session.lastSynthesisError}');
          }
          final sample = PiperSynthesisSample(
            label: label,
            characters: text.runes.length,
            elapsed: watch.elapsed,
            samples: result.audio!.length,
            sampleRate: result.sampleRate,
            rms: rootMeanSquare(result.audio!),
          );
          expect(sample.isSilent, isFalse, reason: '"$label" came out silent');
          return sample;
        }

        for (final label in _sentences.keys) {
          sentences.add(await synthesize(label));
          persist();
        }
        sampleMemory('after_sentences');

        for (var i = 0; i < _consecutiveRuns; i++) {
          consecutive.add(await synthesize('medium'));
          sampleMemory('consecutive_${i + 1}');
          persist();
        }
      } catch (error) {
        persist(failure: '$error');
        rethrow;
      } finally {
        await session.dispose();
      }

      final path = persist();
      // Line by line: the device log truncates long lines.
      // ignore: avoid_print
      print('=== Piper iOS synthesis: $path ===');
      for (final line in File(path).readAsLinesSync()) {
        // ignore: avoid_print
        print(line);
      }
    },
    skip: !Platform.isIOS,
    timeout: Timeout.none,
  );
}

/// Downloads the model and dictionary with the app's downloader if they are
/// not already in place.
Future<void> _ensureModelAndDictionary(
  String piperDir,
  String dicDir,
  String modelName,
) async {
  final client = http.Client();
  try {
    final service = PiperModelDownloadService(client: client);
    if (!service.areModelsDownloaded(piperDir, modelName)) {
      await service.downloadModels(piperDir, modelName);
    }
    await service.downloadDictionary(dicDir);
  } finally {
    client.close();
  }
}

/// Phonemizes [text] as Japanese with a native engine of its own.
PiperPhonemization _phonemize(String modelPath, String dicDir, String text) {
  final bindings = PiperNativeBindings.open();
  final config = calloc<PiperPlusConfig>();
  final outEngine = calloc<Pointer<Void>>();
  final result = calloc<PiperPlusPhonemeResult>();
  final modelPathPtr = modelPath.toNativeUtf8();
  final dicDirPtr = dicDir.toNativeUtf8();
  final textPtr = text.toNativeUtf8();
  final languagePtr = 'ja'.toNativeUtf8();
  try {
    // calloc zero-fills, which the C API requires of the reserved fields; a
    // null config_path means <model>.onnx.json.
    config.ref
      ..modelPath = modelPathPtr
      ..dictDir = dicDirPtr;
    if (bindings.create(config, outEngine) != piperPlusOk) {
      fail(
        'piper_plus_create failed: ${bindings.getLastError().toDartString()}',
      );
    }
    final engine = outEngine.value;
    try {
      if (bindings.phonemize(engine, textPtr, languagePtr, result) !=
          piperPlusOk) {
        fail(
          'piper_plus_phonemize failed: '
          '${bindings.getLastError().toDartString()}',
        );
      }
      // Borrowed until the next call on this engine: read it now.
      return PiperPhonemization(
        text: text,
        language: result.ref.language == nullptr
            ? ''
            : result.ref.language.toDartString(),
        phonemeCount: result.ref.numPhonemes,
        phonemes: result.ref.phonemes == nullptr
            ? ''
            : result.ref.phonemes.toDartString(),
      );
    } finally {
      bindings.free(engine);
    }
  } finally {
    calloc.free(languagePtr);
    calloc.free(textPtr);
    calloc.free(dicDirPtr);
    calloc.free(modelPathPtr);
    calloc.free(result);
    calloc.free(outEngine);
    calloc.free(config);
  }
}

/// Bytes the process may still allocate before jetsam terminates it, from
/// `os_proc_available_memory` (iOS 13+). Null where the symbol is absent.
int? _availableMemory() {
  final process = DynamicLibrary.process();
  if (!process.providesSymbol('os_proc_available_memory')) return null;
  final fn = process.lookupFunction<Size Function(), int Function()>(
    'os_proc_available_memory',
  );
  return fn();
}
