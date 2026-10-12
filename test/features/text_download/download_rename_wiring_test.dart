import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:novel_viewer/features/text_download/providers/episode_rename_propagation.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';
import 'package:path/path.dart' as p;

class _StubSite extends Fake implements NovelSite {}

class _FakeRegistry extends Fake implements NovelSiteRegistry {
  @override
  NovelSite? findSite(Uri url) => _StubSite();
}

class _FakeNovelRepository extends Fake implements NovelRepository {
  @override
  Future<void> upsert(NovelMetadata metadata) async {}

  @override
  Future<NovelMetadata?> findByFolderName(String folderName) async =>
      NovelMetadata(
        siteType: 'narou',
        novelId: 'n1234ab',
        title: 'テスト小説',
        url: 'https://ncode.syosetu.com/n1234ab/',
        folderName: folderName,
        episodeCount: 9,
        downloadedAt: DateTime(2026),
      );
}

/// Renames one file the way the migration would, then either finishes or is
/// cancelled while fetching.
class _RenamingDownloadService extends Fake implements DownloadService {
  _RenamingDownloadService({
    required this.cancelAfterRename,
    required this.failAfterRename,
  });

  final bool cancelAfterRename;
  final bool failAfterRename;

  @override
  String buildFolderName(NovelSite site, Uri url) => 'narou_n1234ab';

  @override
  Future<DownloadResult> downloadNovel({
    required NovelSite site,
    required Uri url,
    required String outputPath,
    EpisodeCacheRepository? episodeCacheRepository,
    ProgressCallback? onProgress,
    CancellationToken? cancelToken,
    EpisodeFilesRenamedCallback? onEpisodeFilesRenamed,
  }) async {
    await onEpisodeFilesRenamed?.call({'9_x.txt': '09_x.txt'});
    if (cancelAfterRename) throw const CancelledException();
    if (failAfterRename) throw Exception('index page 2 failed');
    return DownloadResult(
      siteType: 'narou',
      novelId: 'n1234ab',
      title: 'テスト小説',
      folderName: 'narou_n1234ab',
      episodeCount: 12,
      url: url,
    );
  }

  @override
  void dispose() {}
}

class _RecordingPropagator implements EpisodeRenamePropagator {
  final calls = <({String folder, Map<String, String> renames})>[];

  @override
  Future<void> propagate({
    required String novelFolderPath,
    required Map<String, String> renames,
  }) async {
    calls.add((folder: novelFolderPath, renames: renames));
  }
}

void main() {
  final url = Uri.parse('https://ncode.syosetu.com/n1234ab/');
  final outputPath = p.join('library', 'organized');

  ({ProviderContainer container, _RecordingPropagator propagator}) setUpWith({
    bool cancelAfterRename = false,
    bool failAfterRename = false,
  }) {
    final propagator = _RecordingPropagator();
    final container = ProviderContainer(
      overrides: [
        novelSiteRegistryProvider.overrideWithValue(_FakeRegistry()),
        novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
        downloadServiceFactoryProvider.overrideWithValue(
          () => _RenamingDownloadService(
            cancelAfterRename: cancelAfterRename,
            failAfterRename: failAfterRename,
          ),
        ),
        episodeRenamePropagatorProvider.overrideWithValue(propagator),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, propagator: propagator);
  }

  test('a download propagates the renames of its novel folder', () async {
    final (:container, :propagator) = setUpWith();

    await container
        .read(downloadProvider.notifier)
        .startDownload(url: url, outputPath: outputPath);

    expect(propagator.calls, hasLength(1));
    expect(
      p.equals(
        propagator.calls.single.folder,
        p.join(outputPath, 'narou_n1234ab'),
      ),
      isTrue,
    );
    expect(propagator.calls.single.renames, {'9_x.txt': '09_x.txt'});
  });

  test('a refresh propagates into the folder it updates in place', () async {
    final (:container, :propagator) = setUpWith();

    await container
        .read(downloadProvider.notifier)
        .refreshNovel('narou_n1234ab', parentPath: outputPath);

    expect(container.read(downloadProvider).status, DownloadStatus.completed);
    expect(
      p.equals(
        propagator.calls.single.folder,
        p.join(outputPath, 'narou_n1234ab'),
      ),
      isTrue,
    );
  });

  test('a cancelled download has already propagated', () async {
    final (:container, :propagator) = setUpWith(cancelAfterRename: true);

    await container
        .read(downloadProvider.notifier)
        .refreshNovel('narou_n1234ab', parentPath: outputPath);

    expect(container.read(downloadProvider).status, DownloadStatus.cancelled);
    expect(propagator.calls.single.renames, {'9_x.txt': '09_x.txt'});
  });

  test('a failed download has already propagated', () async {
    final (:container, :propagator) = setUpWith(failAfterRename: true);

    await container
        .read(downloadProvider.notifier)
        .refreshNovel('narou_n1234ab', parentPath: outputPath);

    expect(container.read(downloadProvider).status, DownloadStatus.error);
    expect(propagator.calls.single.renames, {'9_x.txt': '09_x.txt'});
  });
}
