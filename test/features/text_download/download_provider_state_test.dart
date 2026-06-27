import 'dart:async';
import 'dart:io' show Directory, HttpException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeNovelRepository extends Fake implements NovelRepository {
  final NovelMetadata? byFolderName;

  _FakeNovelRepository({this.byFolderName});

  @override
  Future<void> upsert(NovelMetadata metadata) async {}

  @override
  Future<NovelMetadata?> findByFolderName(String folderName) async =>
      byFolderName;
}

/// A [DownloadService] whose [downloadNovel] is fully controlled by the test.
class _ProgrammableService extends DownloadService {
  final DownloadResult Function() resultBuilder;
  final bool throwCancelled;

  /// Simulates an in-flight request aborted by `_client.close()`: cancels the
  /// token then throws a non-[CancelledException] (as `http.Client.close()`
  /// does via `ClientException`), e.g. during the first index fetch.
  final bool cancelThenThrowClientError;
  final Completer<void>? gate;
  CancellationToken? capturedToken;
  int downloadCalls = 0;

  _ProgrammableService({
    required this.resultBuilder,
    this.throwCancelled = false,
    this.cancelThenThrowClientError = false,
    this.gate,
  }) : super(client: MockClient((_) async => http.Response('', 200)));

  @override
  Future<DownloadResult> downloadNovel({
    required NovelSite site,
    required Uri url,
    required String outputPath,
    episodeCacheRepository,
    ProgressCallback? onProgress,
    CancellationToken? cancelToken,
  }) async {
    downloadCalls++;
    capturedToken = cancelToken;
    if (gate != null) await gate!.future;
    if (cancelThenThrowClientError) {
      cancelToken?.cancel();
      throw const HttpException('Connection closed before full header');
    }
    if (throwCancelled) throw const CancelledException();
    cancelToken?.throwIfCancelled();
    return resultBuilder();
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('download_provider_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  final narouUrl = Uri.parse('https://ncode.syosetu.com/n1234ab/');

  DownloadResult resultWith({bool indexTruncated = false}) => DownloadResult(
        siteType: 'narou',
        novelId: 'n1234ab',
        title: 'テスト小説',
        folderName: 'narou_n1234ab',
        episodeCount: 3,
        failedCount: 0,
        indexTruncated: indexTruncated,
        url: narouUrl,
      );

  ProviderContainer makeContainer(DownloadService service,
      {NovelMetadata? metadata}) {
    final container = ProviderContainer(
      overrides: [
        libraryPathProvider.overrideWithValue(tempDir.path),
        novelRepositoryProvider
            .overrideWithValue(_FakeNovelRepository(byFolderName: metadata)),
        downloadServiceFactoryProvider.overrideWithValue(() => service),
        episodeCacheDatabaseProvider.overrideWith((ref, key) {
          final db = EpisodeCacheDatabase(tempDir.path);
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('DownloadNotifier state mapping', () {
    test('indexTruncated from DownloadResult propagates to state', () async {
      final service =
          _ProgrammableService(resultBuilder: () => resultWith(indexTruncated: true));
      final container = makeContainer(service);

      await container
          .read(downloadProvider.notifier)
          .startDownload(url: narouUrl, outputPath: tempDir.path);

      final state = container.read(downloadProvider);
      expect(state.status, DownloadStatus.completed);
      expect(state.indexTruncated, isTrue);
    });

    test('a fully fetched index leaves indexTruncated false', () async {
      final service = _ProgrammableService(resultBuilder: () => resultWith());
      final container = makeContainer(service);

      await container
          .read(downloadProvider.notifier)
          .startDownload(url: narouUrl, outputPath: tempDir.path);

      expect(container.read(downloadProvider).indexTruncated, isFalse);
    });

    test('refreshNovel on a web collection does not run the novel download '
        'path (no stray folder / wrong re-download)', () async {
      final service = _ProgrammableService(resultBuilder: () => resultWith());
      final container = makeContainer(
        service,
        metadata: NovelMetadata(
          siteType: 'web',
          novelId: 'research',
          title: '研究コレクション',
          url: 'https://blog.example.com/article',
          folderName: 'web_research',
          episodeCount: 2,
          downloadedAt: DateTime(2026, 1, 1),
        ),
      );

      await container
          .read(downloadProvider.notifier)
          .refreshNovel('web_research', parentPath: tempDir.path);

      // The whole-novel download path must NOT run for a collection: doing so
      // would create a web_<hash> folder and pull a single stale article URL.
      expect(service.downloadCalls, 0);
      expect(container.read(downloadProvider).status, DownloadStatus.error);
    });

    test('CancelledException maps to the cancelled status (not error)',
        () async {
      final service = _ProgrammableService(
        resultBuilder: () => resultWith(),
        throwCancelled: true,
      );
      final container = makeContainer(service);

      await container
          .read(downloadProvider.notifier)
          .startDownload(url: narouUrl, outputPath: tempDir.path);

      expect(container.read(downloadProvider).status, DownloadStatus.cancelled);
    });

    test('cancellation surfacing as a non-CancelledException (in-flight client '
        'close) still maps to cancelled, not error', () async {
      final service = _ProgrammableService(
        resultBuilder: () => resultWith(),
        cancelThenThrowClientError: true,
      );
      final container = makeContainer(service);

      await container
          .read(downloadProvider.notifier)
          .startDownload(url: narouUrl, outputPath: tempDir.path);

      expect(container.read(downloadProvider).status, DownloadStatus.cancelled);
    });

    test('a genuine error (token not cancelled) still maps to error', () async {
      final service = _ProgrammableService(
        resultBuilder: () => throw const HttpException('boom'),
      );
      final container = makeContainer(service);

      await container
          .read(downloadProvider.notifier)
          .startDownload(url: narouUrl, outputPath: tempDir.path);

      expect(container.read(downloadProvider).status, DownloadStatus.error);
    });

    test('EmptyIndexException (F118) maps to error with a dedicated message',
        () async {
      final service = _ProgrammableService(
        resultBuilder: () => throw EmptyIndexException(narouUrl),
      );
      final container = makeContainer(service);

      await container
          .read(downloadProvider.notifier)
          .startDownload(url: narouUrl, outputPath: tempDir.path);

      final state = container.read(downloadProvider);
      expect(state.status, DownloadStatus.error);
      // Not the raw exception string, and not the unsupported-site message.
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('目次を取得できませんでした'));
    });

    test('a second startDownload while one is in flight is ignored', () async {
      final gate = Completer<void>();
      final service = _ProgrammableService(
        resultBuilder: () => resultWith(),
        gate: gate,
      );
      final container = makeContainer(service);
      final notifier = container.read(downloadProvider.notifier);

      final first =
          notifier.startDownload(url: narouUrl, outputPath: tempDir.path);
      await Future<void>.delayed(Duration.zero); // reach gated downloadNovel

      // Second call must be ignored while the first is still in flight.
      await notifier.startDownload(url: narouUrl, outputPath: tempDir.path);
      expect(container.read(downloadProvider).status,
          DownloadStatus.downloading);
      expect(service.downloadCalls, 1);

      gate.complete();
      await first;
      expect(container.read(downloadProvider).status, DownloadStatus.completed);
    });

    test('cancel() cancels the in-flight token and yields cancelled status',
        () async {
      final gate = Completer<void>();
      final service = _ProgrammableService(
        resultBuilder: () => resultWith(),
        gate: gate,
      );
      final container = makeContainer(service);

      final future = container
          .read(downloadProvider.notifier)
          .startDownload(url: narouUrl, outputPath: tempDir.path);

      // Let startDownload reach the gated downloadNovel call.
      await Future<void>.delayed(Duration.zero);
      container.read(downloadProvider.notifier).cancel();
      gate.complete();
      await future;

      expect(service.capturedToken, isNotNull);
      expect(service.capturedToken!.isCancelled, isTrue);
      expect(container.read(downloadProvider).status, DownloadStatus.cancelled);
    });
  });
}
