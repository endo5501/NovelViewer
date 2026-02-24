import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_model_download_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('tts_provider_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('modelsDirectoryPathProvider', () {
    test('returns parent of library path + models', () {
      final container = ProviderContainer(
        overrides: [
          libraryPathProvider
              .overrideWithValue('${tempDir.path}/NovelViewer'),
        ],
      );
      addTearDown(container.dispose);

      final modelsPath = container.read(modelsDirectoryPathProvider);
      expect(modelsPath, p.join(tempDir.path, 'models'));
    });

    test('returns null when library path is null', () {
      final container = ProviderContainer(
        overrides: [
          libraryPathProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final modelsPath = container.read(modelsDirectoryPathProvider);
      expect(modelsPath, isNull);
    });
  });

  group('ttsModelDownloadProvider', () {
    ProviderContainer createContainer({
      required http.Client httpClient,
      String? libraryPath,
    }) {
      return ProviderContainer(
        overrides: [
          libraryPathProvider
              .overrideWithValue(libraryPath ?? '${tempDir.path}/NovelViewer'),
          sharedPreferencesProvider.overrideWithValue(prefs),
          httpClientProvider.overrideWithValue(httpClient),
        ],
      );
    }

    test('initial state is idle when models not downloaded', () {
      final container = createContainer(httpClient: http.Client());
      addTearDown(container.dispose);

      final state = container.read(ttsModelDownloadProvider);
      expect(state, isA<TtsModelDownloadIdle>());
    });

    test('initial state is completed when models already exist', () {
      final modelsDir = Directory('${tempDir.path}/models')..createSync();
      File('${modelsDir.path}/qwen3-tts-0.6b-f16.gguf')
          .writeAsStringSync('model');
      File('${modelsDir.path}/qwen3-tts-tokenizer-f16.gguf')
          .writeAsStringSync('tokenizer');
      File('${modelsDir.path}/.tts_models_complete')
          .writeAsStringSync('done');

      final container = createContainer(httpClient: http.Client());
      addTearDown(container.dispose);

      final state = container.read(ttsModelDownloadProvider);
      expect(state, isA<TtsModelDownloadCompleted>());
    });

    test('download transitions to completed and auto-sets model dir',
        () async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final container = createContainer(httpClient: mockClient);
      addTearDown(container.dispose);

      await container
          .read(ttsModelDownloadProvider.notifier)
          .startDownload();

      final state = container.read(ttsModelDownloadProvider);
      expect(state, isA<TtsModelDownloadCompleted>());

      // Model dir should be auto-set
      final modelDir = container.read(ttsModelDirProvider);
      expect(modelDir, p.join(tempDir.path, 'models'));
    });

    test('download transitions to error with user-friendly message on HTTP error',
        () async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(Stream.value([]), 404);
      });

      final container = createContainer(httpClient: mockClient);
      addTearDown(container.dispose);

      await container
          .read(ttsModelDownloadProvider.notifier)
          .startDownload();

      final state = container.read(ttsModelDownloadProvider);
      expect(state, isA<TtsModelDownloadError>());
      final error = state as TtsModelDownloadError;
      expect(error.message, contains('サーバーエラー'));
    });

    test(
        'download transitions to error with user-friendly message on network error',
        () async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.error(const SocketException('Connection refused')),
          200,
          contentLength: 100,
        );
      });

      final container = createContainer(httpClient: mockClient);
      addTearDown(container.dispose);

      await container
          .read(ttsModelDownloadProvider.notifier)
          .startDownload();

      final state = container.read(ttsModelDownloadProvider);
      expect(state, isA<TtsModelDownloadError>());
      final error = state as TtsModelDownloadError;
      expect(error.message, contains('ネットワーク'));
    });

    test('completed state includes models directory path', () async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final container = createContainer(httpClient: mockClient);
      addTearDown(container.dispose);

      await container
          .read(ttsModelDownloadProvider.notifier)
          .startDownload();

      final state = container.read(ttsModelDownloadProvider);
      expect(state, isA<TtsModelDownloadCompleted>());
      final completed = state as TtsModelDownloadCompleted;
      expect(completed.modelsDir, p.join(tempDir.path, 'models'));
    });
  });
}
