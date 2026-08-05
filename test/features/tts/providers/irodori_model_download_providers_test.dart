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
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
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

  group('irodoriModelDownloadProvider - variant switched mid-download', () {
    /// Serves a body that only completes once [release] is closed, so a
    /// download can be held open while the variant is switched underneath it.
    ({http.Client client, StreamController<List<int>> release}) heldClient(
        int totalBytes) {
      final release = StreamController<List<int>>();
      final client = MockClient.streaming((request, _) async {
        return http.StreamedResponse(release.stream, 200,
            contentLength: totalBytes);
      });
      return (client: client, release: release);
    }

    test('an in-flight transfer must not mark the newly selected variant as '
        'downloaded', () async {
      // The body matches the manifest, so without the guard this transfer
      // would complete successfully and set Completed.
      final held = heldClient(5);
      final container = createContainer(httpClient: held.client);
      addTearDown(container.dispose);

      // Mirrors the settings UI watching the provider: without a listener
      // Riverpod rebuilds lazily on the next read, which would overwrite the
      // stale write and hide the defect.
      container.listen(irodoriModelDownloadProvider, (_, _) {});

      final notifier = container.read(irodoriModelDownloadProvider.notifier);
      final future = notifier.startDownload();

      // Switching rebuilds the notifier; the transfer already running belongs
      // to the previous variant and must not speak for the new one.
      await container
          .read(irodoriModelVariantProvider.notifier)
          .setValue(IrodoriModelVariant.v4);

      held.release.add(List.filled(5, 0));
      await held.release.close();
      await future;

      expect(
        container.read(irodoriModelDownloadProvider),
        isNot(isA<IrodoriModelDownloadCompleted>()),
        reason: 'v4 was never downloaded, so it must still offer the download',
      );
    });

    test('cancel reaches the transfer that is actually running', () async {
      // The manifest matches the full 10-byte body, so the file would exist
      // if the transfer ran to completion — its absence is the evidence that
      // the cancel reached the service actually on the wire.
      final held = heldClient(10);
      final container = createContainer(
        httpClient: held.client,
        expectedFileSizes: {
          for (final v in IrodoriModelVariant.values) v: 10,
        },
      );
      addTearDown(container.dispose);

      container.listen(irodoriModelDownloadProvider, (_, _) {});

      final notifier = container.read(irodoriModelDownloadProvider.notifier);
      final future = notifier.startDownload();

      await container
          .read(irodoriModelVariantProvider.notifier)
          .setValue(IrodoriModelVariant.v4);

      // Cancelling after the rebuild must stop the multi-GB transfer that is
      // still on the wire, not a fresh service that owns nothing.
      notifier.cancelDownload();

      held.release.add(List.filled(5, 0));
      await Future<void>.delayed(Duration.zero);
      held.release.add(List.filled(5, 0));
      // Not awaited: once downloadFile cancels its subscription the
      // controller's close() never completes, which would hang the test.
      unawaited(held.release.close());
      await future;

      expect(
        File(p.join(tempDir.path, 'models',
                IrodoriModelVariant.v3.modelDirName,
                IrodoriModelVariant.v3.ggufFileName))
            .existsSync(),
        isFalse,
        reason: 'a cancelled transfer must not leave a finished file',
      );
    });

    test('a second download cannot start while one is in flight', () async {
      final held = heldClient(5);
      final container = createContainer(httpClient: held.client);
      addTearDown(container.dispose);

      container.listen(irodoriModelDownloadProvider, (_, _) {});

      final notifier = container.read(irodoriModelDownloadProvider.notifier);
      final first = notifier.startDownload();

      // The rebuild resets state to idle, which used to defeat the
      // "already downloading" guard and allow a concurrent transfer.
      await container
          .read(irodoriModelVariantProvider.notifier)
          .setValue(IrodoriModelVariant.v4);

      await notifier.startDownload();

      held.release.add(List.filled(5, 0));
      await held.release.close();
      await first;

      expect(
        container.read(irodoriModelDownloadProvider),
        isNot(isA<IrodoriModelDownloadCompleted>()),
      );
    });
  });

  group('irodoriModelDownloadProvider - legacy asset deletion', () {
    test('a delete failure is surfaced instead of escaping as an unhandled '
        'async error', () async {
      // An open handle makes delete(recursive: true) throw on Windows, which
      // is the platform the guard exists for (a memory-mapped model file is
      // the realistic case). POSIX happily unlinks open files, so there is
      // nothing to reproduce there.
      final modelsDir = p.join(tempDir.path, 'models');
      final dir = Directory(p.join(modelsDir, 'llm-jp-3-150m'))
        ..createSync(recursive: true);
      final locked = File(p.join(dir.path, 'locked.bin'))
        ..writeAsBytesSync(List.filled(64, 0));
      final handle = locked.openSync(mode: FileMode.append);
      addTearDown(handle.closeSync);

      final container = createContainer(httpClient: http.Client());
      addTearDown(container.dispose);

      await container
          .read(irodoriModelDownloadProvider.notifier)
          .deleteLegacyAssets();

      expect(dir.existsSync(), isTrue);
      expect(
        container.read(irodoriModelDownloadProvider),
        isA<IrodoriModelDownloadError>(),
        reason: 'the user must be told the cleanup did not happen',
      );
    }, skip: !Platform.isWindows);

    test('the reclaimable size is re-read after a delete', () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final dir = Directory(p.join(modelsDir, 'llm-jp-3-150m'))
        ..createSync(recursive: true);
      File(p.join(dir.path, 'blob.bin')).writeAsBytesSync(List.filled(512, 0));

      final container = createContainer(httpClient: http.Client());
      addTearDown(container.dispose);

      expect(container.read(irodoriLegacyAssetsProvider).present, isTrue);

      await container
          .read(irodoriModelDownloadProvider.notifier)
          .deleteLegacyAssets();

      expect(container.read(irodoriLegacyAssetsProvider).present, isFalse);
    });
  });
}
