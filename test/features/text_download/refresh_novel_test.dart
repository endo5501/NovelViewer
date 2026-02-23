import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';

class _TrackingDownloadNotifier extends DownloadNotifier {
  Uri? lastUrl;
  String? lastOutputPath;
  bool startDownloadCalled = false;

  @override
  Future<void> startDownload({
    required Uri url,
    required String outputPath,
  }) async {
    startDownloadCalled = true;
    lastUrl = url;
    lastOutputPath = outputPath;
    state = DownloadState(
      status: DownloadStatus.completed,
      outputPath: outputPath,
      totalEpisodes: 5,
    );
  }

  void simulateDownloading() {
    state = const DownloadState(status: DownloadStatus.downloading);
  }
}

class _FakeNovelRepository extends Fake implements NovelRepository {
  final NovelMetadata? _result;
  String? lastFolderName;

  _FakeNovelRepository(this._result);

  @override
  Future<NovelMetadata?> findByFolderName(String folderName) async {
    lastFolderName = folderName;
    return _result;
  }
}

void main() {
  final testMetadata = NovelMetadata(
    id: 1,
    siteType: 'narou',
    novelId: 'n1234ab',
    title: 'テスト小説',
    url: 'https://ncode.syosetu.com/n1234ab/',
    folderName: 'narou_n1234ab',
    episodeCount: 10,
    downloadedAt: DateTime(2024, 1, 1),
  );

  group('DownloadNotifier.refreshNovel', () {
    test('fetches metadata by folderName and calls startDownload with stored URL',
        () async {
      final fakeRepo = _FakeNovelRepository(testMetadata);
      final trackingNotifier = _TrackingDownloadNotifier();

      final container = ProviderContainer(
        overrides: [
          novelRepositoryProvider.overrideWithValue(fakeRepo),
          libraryPathProvider.overrideWithValue('/tmp/test_novels'),
          downloadProvider.overrideWith(() => trackingNotifier),
        ],
      );
      addTearDown(container.dispose);

      // Initialize the notifier
      container.read(downloadProvider);

      await container
          .read(downloadProvider.notifier)
          .refreshNovel('narou_n1234ab');

      expect(fakeRepo.lastFolderName, 'narou_n1234ab');
      expect(
        trackingNotifier.lastUrl,
        Uri.parse('https://ncode.syosetu.com/n1234ab/'),
      );
      expect(trackingNotifier.lastOutputPath, '/tmp/test_novels');
      expect(
        container.read(downloadProvider).status,
        DownloadStatus.completed,
      );
    });

    test('does nothing when download is already in progress', () async {
      final fakeRepo = _FakeNovelRepository(testMetadata);
      final trackingNotifier = _TrackingDownloadNotifier();

      final container = ProviderContainer(
        overrides: [
          novelRepositoryProvider.overrideWithValue(fakeRepo),
          libraryPathProvider.overrideWithValue('/tmp/test_novels'),
          downloadProvider.overrideWith(() => trackingNotifier),
        ],
      );
      addTearDown(container.dispose);

      // Initialize and set downloading state
      container.read(downloadProvider);
      trackingNotifier.simulateDownloading();
      expect(
        container.read(downloadProvider).status,
        DownloadStatus.downloading,
      );

      await container
          .read(downloadProvider.notifier)
          .refreshNovel('narou_n1234ab');

      // Should still be downloading (unchanged)
      expect(
        container.read(downloadProvider).status,
        DownloadStatus.downloading,
      );
      expect(trackingNotifier.startDownloadCalled, isFalse);
    });

    test('sets error state when metadata is not found', () async {
      final fakeRepo = _FakeNovelRepository(null);

      final container = ProviderContainer(
        overrides: [
          novelRepositoryProvider.overrideWithValue(fakeRepo),
          libraryPathProvider.overrideWithValue('/tmp/test_novels'),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(downloadProvider.notifier)
          .refreshNovel('unknown_folder');

      expect(
        container.read(downloadProvider).status,
        DownloadStatus.error,
      );
      expect(
        container.read(downloadProvider).errorMessage,
        '小説のメタデータが見つかりません',
      );
    });
  });
}
