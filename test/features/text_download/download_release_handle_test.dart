import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';

class _StubSite extends Fake implements NovelSite {}

class _FakeRegistry extends Fake implements NovelSiteRegistry {
  final NovelSite site;
  _FakeRegistry(this.site);

  @override
  NovelSite? findSite(Uri url) => site;
}

class _FakeNovelRepository extends Fake implements NovelRepository {
  @override
  Future<void> upsert(NovelMetadata metadata) async {}
}

/// A download service whose `downloadNovel` outcome is configurable, so the
/// test can exercise both the success and failure branches of `startDownload`.
class _ConfigurableDownloadService extends Fake implements DownloadService {
  final bool throws;
  _ConfigurableDownloadService({required this.throws});

  @override
  String buildFolderName(NovelSite site, Uri url) => 'narou_n1234ab';

  @override
  Future<DownloadResult> downloadNovel({
    required NovelSite site,
    required Uri url,
    required String outputPath,
    EpisodeCacheRepository? episodeCacheRepository,
    ProgressCallback? onProgress,
  }) async {
    if (throws) throw Exception('boom');
    return DownloadResult(
      siteType: 'narou',
      novelId: 'n1234ab',
      title: 'テスト小説',
      folderName: 'narou_n1234ab',
      episodeCount: 1,
      url: url,
    );
  }

  @override
  void dispose() {}
}

void main() {
  const outputPath = '/tmp/test_novels';
  final url = Uri.parse('https://ncode.syosetu.com/n1234ab/');
  final cacheKey = folderDbKey(p.join(outputPath, 'narou_n1234ab'));

  ProviderContainer makeContainer({required bool throws}) {
    return ProviderContainer(
      overrides: [
        novelSiteRegistryProvider.overrideWithValue(_FakeRegistry(_StubSite())),
        novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
        downloadServiceFactoryProvider
            .overrideWithValue(() => _ConfigurableDownloadService(throws: throws)),
      ],
    );
  }

  group('startDownload releases the episode_cache handle', () {
    test('released after a successful download', () async {
      final container = makeContainer(throws: false);
      addTearDown(container.dispose);

      final before = container.read(episodeCacheDatabaseProvider(cacheKey));
      await container
          .read(downloadProvider.notifier)
          .startDownload(url: url, outputPath: outputPath);
      final after = container.read(episodeCacheDatabaseProvider(cacheKey));

      expect(container.read(downloadProvider).status, DownloadStatus.completed);
      expect(identical(before, after), isFalse,
          reason: 'handle SHALL be released (family entry invalidated) on '
              'successful download');
    });

    test('released after a failed download', () async {
      final container = makeContainer(throws: true);
      addTearDown(container.dispose);

      final before = container.read(episodeCacheDatabaseProvider(cacheKey));
      await container
          .read(downloadProvider.notifier)
          .startDownload(url: url, outputPath: outputPath);
      final after = container.read(episodeCacheDatabaseProvider(cacheKey));

      expect(container.read(downloadProvider).status, DownloadStatus.error);
      expect(identical(before, after), isFalse,
          reason: 'handle SHALL be released (family entry invalidated) even '
              'when the download throws');
    });
  });

  // Guards that the cached instance type is what we think it is, so the
  // identity check above is meaningful.
  test('episode cache provider yields EpisodeCacheDatabase', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(episodeCacheDatabaseProvider(cacheKey)),
        isA<EpisodeCacheDatabase>());
  });
}
