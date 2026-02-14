import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

enum DownloadStatus { idle, downloading, completed, error }

class DownloadState {
  final DownloadStatus status;
  final int currentEpisode;
  final int totalEpisodes;
  final int skippedEpisodes;
  final String? errorMessage;
  final String? outputPath;

  const DownloadState({
    this.status = DownloadStatus.idle,
    this.currentEpisode = 0,
    this.totalEpisodes = 0,
    this.skippedEpisodes = 0,
    this.errorMessage,
    this.outputPath,
  });

  DownloadState copyWith({
    DownloadStatus? status,
    int? currentEpisode,
    int? totalEpisodes,
    int? skippedEpisodes,
    String? errorMessage,
    String? outputPath,
  }) {
    return DownloadState(
      status: status ?? this.status,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      skippedEpisodes: skippedEpisodes ?? this.skippedEpisodes,
      errorMessage: errorMessage ?? this.errorMessage,
      outputPath: outputPath ?? this.outputPath,
    );
  }
}

class DownloadNotifier extends Notifier<DownloadState> {
  @override
  DownloadState build() => const DownloadState();

  Future<void> startDownload({
    required Uri url,
    required String outputPath,
  }) async {
    final registry = ref.read(novelSiteRegistryProvider);
    final site = registry.findSite(url);
    if (site == null) {
      state = const DownloadState(
        status: DownloadStatus.error,
        errorMessage: 'サポートされていないサイトです',
      );
      return;
    }

    state = DownloadState(
      status: DownloadStatus.downloading,
      outputPath: outputPath,
    );

    final service = DownloadService();
    final folderName = service.buildFolderName(site, url);
    final novelDirPath = '$outputPath/$folderName';

    final cacheDb = EpisodeCacheDatabase(novelDirPath);
    final cacheRepo = EpisodeCacheRepository(cacheDb);

    try {
      final result = await service.downloadNovel(
        site: site,
        url: url,
        outputPath: outputPath,
        episodeCacheRepository: cacheRepo,
        onProgress: (current, total, skipped) {
          state = state.copyWith(
            currentEpisode: current,
            totalEpisodes: total,
            skippedEpisodes: skipped,
          );
        },
      );

      final repository = ref.read(novelRepositoryProvider);
      await repository.upsert(NovelMetadata(
        siteType: result.siteType,
        novelId: result.novelId,
        title: result.title,
        url: result.url.toString(),
        folderName: result.folderName,
        episodeCount: result.episodeCount,
        downloadedAt: DateTime.now(),
      ));
      ref.invalidate(allNovelsProvider);

      state = state.copyWith(status: DownloadStatus.completed);
    } catch (e) {
      state = state.copyWith(
        status: DownloadStatus.error,
        errorMessage: e.toString(),
      );
    } finally {
      await cacheDb.close();
      service.dispose();
    }
  }

  void reset() {
    state = const DownloadState();
  }
}

final downloadProvider =
    NotifierProvider<DownloadNotifier, DownloadState>(DownloadNotifier.new);

final novelSiteRegistryProvider = Provider<NovelSiteRegistry>((ref) {
  return NovelSiteRegistry();
});
