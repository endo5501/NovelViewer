import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/piper_model_download_service.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/providers/tts_model_readiness_provider.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// The completion marker is only consulted by the settings screen, so a user
/// who presses play without opening settings still loads an incompatible model
/// and only finds out when synthesis fails deep in the native runner. These
/// tests pin the readiness check the synthesis entry points consult instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String piperDir;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('tts_readiness_test_');
    piperDir = p.join(tempDir.path, 'models', 'piper');
    Directory(piperDir).createSync(recursive: true);
    Directory(p.join(piperDir, 'open_jtalk_dic')).createSync();
    File(p.join(piperDir, 'open_jtalk_dic', 'sys.dic')).writeAsStringSync('x');
    for (final name in PiperModelDownloadService.localModelFiles(
      PiperModelDownloadService.defaultModelName,
    )) {
      File(p.join(piperDir, name)).writeAsStringSync('dummy');
    }
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void writeMarker(String content) =>
      File(p.join(piperDir, '.piper_models_complete'))
          .writeAsStringSync(content);

  TtsModelReadiness readinessFor(TtsEngineType engine) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // qwen3 and Irodori derive their model directories from the library
        // path; pointing it at the empty temp tree keeps them "not downloaded".
        libraryPathProvider.overrideWithValue(p.join(tempDir.path, 'library')),
        piperModelDirProvider.overrideWithValue(piperDir),
        piperDicDirProvider
            .overrideWithValue(p.join(piperDir, 'open_jtalk_dic')),
      ],
    );
    addTearDown(container.dispose);
    return container.read(ttsModelReadinessProvider(engine));
  }

  group('piper readiness', () {
    test('is ready when the marker matches the pinned revision', () {
      writeMarker(PiperModelDownloadService.modelRevision);

      expect(readinessFor(TtsEngineType.piper), TtsModelReadiness.ready);
    });

    test('needs a download for a legacy timestamp marker', () {
      writeMarker('2026-06-13T20:23:12.187142');

      expect(
        readinessFor(TtsEngineType.piper),
        TtsModelReadiness.needsDownload,
        reason: 'A pre-pin model must not reach the native runner',
      );
    });

    test('needs a download when the marker holds another revision', () {
      writeMarker('0000000000000000000000000000000000000000');

      expect(
        readinessFor(TtsEngineType.piper),
        TtsModelReadiness.needsDownload,
      );
    });

    test('needs a download when the dictionary is missing', () {
      writeMarker(PiperModelDownloadService.modelRevision);
      Directory(p.join(piperDir, 'open_jtalk_dic')).deleteSync(recursive: true);

      expect(
        readinessFor(TtsEngineType.piper),
        TtsModelReadiness.needsDownload,
      );
    });

    test('needs a download when a model file is missing', () {
      writeMarker(PiperModelDownloadService.modelRevision);
      File(p.join(
        piperDir,
        PiperModelDownloadService.onnxFileName(
          PiperModelDownloadService.defaultModelName,
        ),
      )).deleteSync();

      expect(
        readinessFor(TtsEngineType.piper),
        TtsModelReadiness.needsDownload,
      );
    });
  });

  group('other engines', () {
    // qwen3 and Irodori do not bind their markers to a revision yet, so the
    // check delegates to their existing completeness rules rather than
    // inventing a stricter one here.
    test('report needsDownload when their model files are absent', () {
      expect(
        readinessFor(TtsEngineType.qwen3),
        TtsModelReadiness.needsDownload,
      );
      expect(
        readinessFor(TtsEngineType.irodori),
        TtsModelReadiness.needsDownload,
      );
    });
  });
}
