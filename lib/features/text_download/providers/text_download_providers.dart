import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';
import 'package:path/path.dart' as p;

enum DownloadStatus { idle, downloading, completed, error, cancelled }

class DownloadState {
  final DownloadStatus status;
  final int currentEpisode;
  final int totalEpisodes;
  final int skippedEpisodes;
  final int failedEpisodes;

  /// True when the table of contents could not be fully fetched (F102). Some
  /// episodes may be missing; the UI shows a warning on completion.
  final bool indexTruncated;
  final String? errorMessage;
  final String? outputPath;

  const DownloadState({
    this.status = DownloadStatus.idle,
    this.currentEpisode = 0,
    this.totalEpisodes = 0,
    this.skippedEpisodes = 0,
    this.failedEpisodes = 0,
    this.indexTruncated = false,
    this.errorMessage,
    this.outputPath,
  });

  DownloadState copyWith({
    DownloadStatus? status,
    int? currentEpisode,
    int? totalEpisodes,
    int? skippedEpisodes,
    int? failedEpisodes,
    bool? indexTruncated,
    String? errorMessage,
    String? outputPath,
  }) {
    return DownloadState(
      status: status ?? this.status,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      skippedEpisodes: skippedEpisodes ?? this.skippedEpisodes,
      failedEpisodes: failedEpisodes ?? this.failedEpisodes,
      indexTruncated: indexTruncated ?? this.indexTruncated,
      errorMessage: errorMessage ?? this.errorMessage,
      outputPath: outputPath ?? this.outputPath,
    );
  }
}

class DownloadNotifier extends Notifier<DownloadState> {
  CancellationToken? _cancelToken;

  @override
  DownloadState build() => const DownloadState();

  /// Requests cancellation of the in-progress download (if any). The download
  /// stops at the next safe point, already-saved episodes are kept, and the
  /// state becomes [DownloadStatus.cancelled].
  void cancel() {
    _cancelToken?.cancel();
  }

  Future<void> startDownload({
    required Uri url,
    required String outputPath,
  }) async {
    // Guard against overlapping downloads (e.g. fast repeated taps). A download
    // is in flight exactly while `_cancelToken` is set; this is set
    // synchronously below before the first await and cleared in `finally`.
    // Using the token (not `state.status`) lets `refreshNovel`, which sets the
    // downloading state before delegating here, still proceed.
    if (_cancelToken != null) return;

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

    final service = ref.read(downloadServiceFactoryProvider)();
    final folderName = service.buildFolderName(site, url);
    final novelDirPath = p.join(outputPath, folderName);
    // Canonical family key so the handle opened here can be released later via
    // the file browser's platform-separator path (see [folderDbKey]).
    final cacheKey = folderDbKey(novelDirPath);

    final cacheDb = ref.read(episodeCacheDatabaseProvider(cacheKey));
    final cacheRepo = EpisodeCacheRepository(cacheDb);

    final cancelToken = CancellationToken();
    _cancelToken = cancelToken;

    try {
      final result = await service.downloadNovel(
        site: site,
        url: url,
        outputPath: outputPath,
        episodeCacheRepository: cacheRepo,
        cancelToken: cancelToken,
        onProgress: (current, total, skipped, failed) {
          state = state.copyWith(
            currentEpisode: current,
            totalEpisodes: total,
            skippedEpisodes: skipped,
            failedEpisodes: failed,
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

      state = state.copyWith(
        status: DownloadStatus.completed,
        failedEpisodes: result.failedCount,
        indexTruncated: result.indexTruncated,
      );
    } catch (e) {
      // A user-initiated cancellation is distinct from a failure. It can surface
      // either as a cooperative CancelledException or, when an in-flight request
      // is aborted by closing the client, as a transport error (e.g.
      // ClientException) thrown before any cooperative check is reached (notably
      // during the first index fetch). Map any exception to "cancelled" when the
      // token was cancelled. Episodes saved before cancellation are kept for a
      // later resumed download.
      if (e is CancelledException || cancelToken.isCancelled) {
        state = state.copyWith(status: DownloadStatus.cancelled);
      } else {
        state = state.copyWith(
          status: DownloadStatus.error,
          errorMessage: e.toString(),
        );
      }
    } finally {
      _cancelToken = null;
      service.dispose();
      // Release the episode_cache.db handle opened above so it does not keep
      // the file locked on Windows (which would block a later folder delete).
      // Close the actual instance we hold and AWAIT it (rather than relying on
      // invalidate's fire-and-forget onDispose close), so the OS lock is gone
      // before control returns. Then invalidate to drop the disposed entry.
      // Runs on both success and failure paths. See [folderDbKey].
      await cacheDb.close();
      ref.invalidate(episodeCacheDatabaseProvider(cacheKey));
    }
  }

  Future<void> refreshNovel(String folderName) async {
    if (state.status == DownloadStatus.downloading) {
      return;
    }

    state = const DownloadState(status: DownloadStatus.downloading);

    try {
      final repository = ref.read(novelRepositoryProvider);
      final metadata = await repository.findByFolderName(folderName);
      if (metadata == null) {
        state = const DownloadState(
          status: DownloadStatus.error,
          errorMessage: '小説のメタデータが見つかりません',
        );
        return;
      }

      final libraryPath = ref.read(libraryPathProvider);
      if (libraryPath == null) {
        state = const DownloadState(
          status: DownloadStatus.error,
          errorMessage: 'ライブラリパスが設定されていません',
        );
        return;
      }

      await startDownload(
        url: Uri.parse(metadata.url),
        outputPath: libraryPath,
      );
    } catch (e) {
      state = DownloadState(
        status: DownloadStatus.error,
        errorMessage: '更新に失敗しました: $e',
      );
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

/// Factory for [DownloadService] instances. A new service is created per
/// download (each owns an `http.Client` it disposes when done). Exposed as a
/// provider so tests can inject a fake without performing real network I/O.
final downloadServiceFactoryProvider =
    Provider<DownloadService Function()>((ref) => DownloadService.new);
