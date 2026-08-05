import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_variant.dart';
import 'package:novel_viewer/features/tts/providers/irodori_model_download_providers.dart';

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('irodori_provider_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // A small manifest matching the fake payload sizes the tests' mock HTTP
  // clients and pre-written fixture files use, overriding the real
  // multi-hundred-megabyte-to-gigabyte pinned sizes
  // (IrodoriModelDownloadService.defaultExpectedFileSizes) so fixtures can
  // stay small. Provided by default; individual tests may override further.
  final testExpectedFileSizes = <IrodoriModelVariant, int>{
    for (final v in IrodoriModelVariant.values) v: 5,
  };

  ProviderContainer createContainer({
    required http.Client httpClient,
    String? libraryPath,
    Map<IrodoriModelVariant, int>? expectedFileSizes,
  }) {
    return ProviderContainer(
      overrides: [
        libraryPathProvider
            .overrideWithValue(libraryPath ?? '${tempDir.path}/NovelViewer'),
        sharedPreferencesProvider.overrideWithValue(prefs),
        httpClientProvider.overrideWithValue(httpClient),
        irodoriExpectedFileSizesProvider.overrideWithValue(
          expectedFileSizes ?? testExpectedFileSizes,
        ),
      ],
    );
  }

  /// Places the selected variant's single GGUF, sized to match the manifest
  /// above. The GGUF embeds spec/config/tokenizer, so no sibling directories.
  void writeAllRequiredFiles(
    String modelsDir, {
    IrodoriModelVariant variant = IrodoriModelVariant.v3,
  }) {
    final dir = Directory(p.join(modelsDir, variant.modelDirName))
      ..createSync(recursive: true);
    File(p.join(dir.path, variant.ggufFileName))
        .writeAsBytesSync(List.filled(testExpectedFileSizes[variant]!, 0));
  }

  group('irodoriModelDownloadProvider', () {
    test('initial state is idle when models are not downloaded', () {
      final container = createContainer(httpClient: http.Client());
      addTearDown(container.dispose);

      final state = container.read(irodoriModelDownloadProvider);
      expect(state, isA<IrodoriModelDownloadIdle>());
    });

    test('initial state is completed when all required files already exist',
        () {
      final modelsDir = p.join(tempDir.path, 'models');
      writeAllRequiredFiles(modelsDir);

      final container = createContainer(
        httpClient: http.Client(),
        expectedFileSizes: {
          for (final v in IrodoriModelVariant.values) v: 5,
        },
      );
      addTearDown(container.dispose);

      final state = container.read(irodoriModelDownloadProvider);
      expect(state, isA<IrodoriModelDownloadCompleted>());
      expect((state as IrodoriModelDownloadCompleted).modelsDir, modelsDir);
    });

    test('initial state is idle when library path is not set', () {
      final container = createContainer(
        httpClient: http.Client(),
        libraryPath: null,
      );
      addTearDown(container.dispose);

      final state = container.read(irodoriModelDownloadProvider);
      expect(state, isA<IrodoriModelDownloadIdle>());
    });

    test('download transitions to completed', () async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value(List.filled(5, 0)),
          200,
          contentLength: 5,
        );
      });

      final container = createContainer(httpClient: mockClient);
      addTearDown(container.dispose);

      await container
          .read(irodoriModelDownloadProvider.notifier)
          .startDownload();

      final state = container.read(irodoriModelDownloadProvider);
      expect(state, isA<IrodoriModelDownloadCompleted>());
    });

    test('reports downloading state with per-file progress', () async {
      final progressUpdates = <IrodoriModelDownloadDownloading>[];
      final mockClient = MockClient.streaming((request, _) async {
        final bytes = List.filled(10, 0);
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: 10,
        );
      });

      final container = createContainer(
        httpClient: mockClient,
        expectedFileSizes: {
          for (final v in IrodoriModelVariant.values) v: 10,
        },
      );
      addTearDown(container.dispose);

      container.listen(
        irodoriModelDownloadProvider,
        (previous, next) {
          if (next is IrodoriModelDownloadDownloading) {
            progressUpdates.add(next);
          }
        },
      );

      await container
          .read(irodoriModelDownloadProvider.notifier)
          .startDownload();

      expect(progressUpdates, isNotEmpty);
      expect(
        progressUpdates
            .any((s) => s.currentFile == IrodoriModelVariant.v3.ggufFileName),
        isTrue,
      );
    });

    test('download transitions to error on HTTP error', () async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(Stream.value([]), 404);
      });

      final container = createContainer(httpClient: mockClient);
      addTearDown(container.dispose);

      await container
          .read(irodoriModelDownloadProvider.notifier)
          .startDownload();

      final state = container.read(irodoriModelDownloadProvider);
      expect(state, isA<IrodoriModelDownloadError>());
      final error = state as IrodoriModelDownloadError;
      expect(error.message, contains('サーバーエラー'));
    });

    test('download transitions to error on network error', () async {
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
          .read(irodoriModelDownloadProvider.notifier)
          .startDownload();

      final state = container.read(irodoriModelDownloadProvider);
      expect(state, isA<IrodoriModelDownloadError>());
      final error = state as IrodoriModelDownloadError;
      expect(error.message, contains('ネットワーク'));
    });

    test('cancelDownload() returns to idle instead of error', () async {
      final chunkController = StreamController<List<int>>();
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          chunkController.stream,
          200,
          contentLength: 20,
        );
      });

      // A variant is a single file, so there is no next-file loop boundary
      // for the cancel flag to be observed at — it has to be caught inside
      // the stream. Two chunks are sent: the first raises progress (which
      // triggers the cancel below), the second gives downloadFile a chunk
      // boundary at which to notice it.
      final container = createContainer(
        httpClient: mockClient,
        expectedFileSizes: {
          for (final v in IrodoriModelVariant.values) v: 20,
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(irodoriModelDownloadProvider.notifier);

      // Cancel synchronously as soon as the first progress update lands,
      // rather than racing real filesystem I/O with an arbitrary delay.
      container.listen(irodoriModelDownloadProvider, (previous, next) {
        if (next is IrodoriModelDownloadDownloading &&
            (next.progress ?? 0) > 0) {
          notifier.cancelDownload();
        }
      });

      final future = notifier.startDownload();

      chunkController.add(List.filled(10, 0));
      await Future<void>.delayed(Duration.zero);
      chunkController.add(List.filled(10, 0));
      await chunkController.close();

      await future;

      final state = container.read(irodoriModelDownloadProvider);
      expect(state, isA<IrodoriModelDownloadIdle>());
    });

    test('completed state includes the models root directory path',
        () async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value(List.filled(5, 0)),
          200,
          contentLength: 5,
        );
      });

      final container = createContainer(httpClient: mockClient);
      addTearDown(container.dispose);

      await container
          .read(irodoriModelDownloadProvider.notifier)
          .startDownload();

      final state = container.read(irodoriModelDownloadProvider);
      expect(state, isA<IrodoriModelDownloadCompleted>());
      final completed = state as IrodoriModelDownloadCompleted;
      expect(completed.modelsDir, p.join(tempDir.path, 'models'));
    });
  });
}
