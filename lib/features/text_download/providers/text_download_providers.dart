import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'dart:io';

import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/generic_web_site.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry_provider.dart';
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
      await repository.upsert(
        NovelMetadata(
          siteType: result.siteType,
          novelId: result.novelId,
          title: result.title,
          url: result.url.toString(),
          folderName: result.folderName,
          episodeCount: result.episodeCount,
          downloadedAt: DateTime.now(),
        ),
      );
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
      } else if (e is EmptyIndexException) {
        // F118: the index page yielded no episodes and no body — typically the
        // site changed its markup, or the URL is not a novel index page. Surface
        // a clear message instead of the raw exception string, and do not leave
        // a half-finished "completed" state. (Localizing provider-layer error
        // strings is tracked separately as F142.)
        state = state.copyWith(
          status: DownloadStatus.error,
          errorMessage: '目次を取得できませんでした。サイトの仕様変更か、URLが正しくない可能性があります',
        );
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
      // Close ONLY the episode cache (not the folder's TTS handles, which other
      // consumers may be using): the registry closes it (awaited) and evicts,
      // so the OS lock is gone before control returns. Then invalidate to drop
      // the thin-view provider's reference. Runs on both success and failure
      // paths. See [folderDbKey].
      await ref.read(perFolderDbRegistryProvider).closeEpisodeCache(cacheKey);
      ref.invalidate(episodeCacheDatabaseProvider(cacheKey));
    }
  }

  /// Imports a single generic web article into a collection (theme folder).
  ///
  /// Always uses [GenericWebSite] (single-page extraction), regardless of
  /// whether the URL also matches a specialized site — "add this page to a
  /// collection" treats the page as a plain article.
  ///
  /// Exactly one of [existingCollectionPath] / [newCollectionName] selects the
  /// destination: an existing collection folder is appended to, otherwise a new
  /// `web_<slug>` collection is created. When [newCollectionName] is blank, the
  /// fetched article title is used as the collection name.
  Future<void> startCollectionDownload({
    required Uri url,
    required String libraryPath,
    String? existingCollectionPath,
    String? newCollectionName,
  }) async {
    if (_cancelToken != null) return;

    final site = GenericWebSite();
    state = const DownloadState(status: DownloadStatus.downloading);

    final service = ref.read(downloadServiceFactoryProvider)();
    final cancelToken = CancellationToken();
    _cancelToken = cancelToken;
    String? cacheKey;

    try {
      final normalized = site.normalizeUrl(url);
      final article = await service.fetchArticle(
        site: site,
        url: normalized,
        cancelToken: cancelToken,
      );

      final Directory collectionDir;
      final String folderName;
      final String novelId;
      final String collectionTitle;
      if (existingCollectionPath != null) {
        collectionDir = Directory(existingCollectionPath);
        folderName = p.basename(existingCollectionPath);
        novelId =
            folderName.startsWith('web_') ? folderName.substring(4) : folderName;
        final existingMeta =
            await ref.read(novelRepositoryProvider).findByFolderName(folderName);
        collectionTitle = existingMeta?.title ?? novelId;
      } else {
        final name = (newCollectionName?.trim().isNotEmpty ?? false)
            ? newCollectionName!.trim()
            : article.title;
        final created =
            await service.createCollectionDirectory(libraryPath, name);
        collectionDir = created.dir;
        folderName = created.folderName;
        novelId = created.novelId;
        collectionTitle = name;
      }

      cacheKey = folderDbKey(collectionDir.path);
      final cacheDb = ref.read(episodeCacheDatabaseProvider(cacheKey));
      final cacheRepo = EpisodeCacheRepository(cacheDb);

      await service.saveArticleToCollection(
        collectionDir: collectionDir,
        url: normalized,
        article: article,
        episodeCacheRepository: cacheRepo,
      );

      final episodeCount = collectionDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.txt'))
          .length;

      await ref.read(novelRepositoryProvider).upsert(
            NovelMetadata(
              siteType: 'web',
              novelId: novelId,
              title: collectionTitle,
              url: normalized.toString(),
              folderName: folderName,
              episodeCount: episodeCount,
              downloadedAt: DateTime.now(),
            ),
          );
      ref.invalidate(allNovelsProvider);

      state = state.copyWith(
        status: DownloadStatus.completed,
        totalEpisodes: episodeCount,
      );
    } catch (e) {
      if (e is CancelledException || cancelToken.isCancelled) {
        state = state.copyWith(status: DownloadStatus.cancelled);
      } else if (e is EmptyIndexException) {
        state = state.copyWith(
          status: DownloadStatus.error,
          errorMessage:
              '本文を抽出できませんでした。JavaScriptで描画されるページか、本文の少ないページの可能性があります',
        );
      } else {
        state = state.copyWith(
          status: DownloadStatus.error,
          errorMessage: e.toString(),
        );
      }
    } finally {
      _cancelToken = null;
      service.dispose();
      if (cacheKey != null) {
        await ref.read(perFolderDbRegistryProvider).closeEpisodeCache(cacheKey);
        ref.invalidate(episodeCacheDatabaseProvider(cacheKey));
      }
    }
  }

  /// Creates an empty `web` collection folder (no articles yet) so the user can
  /// add pages to it later via [startCollectionDownload]. Registers metadata so
  /// it appears in the library and in the "add to existing collection" picker.
  Future<void> createEmptyCollection({
    required String name,
    required String libraryPath,
  }) async {
    final service = ref.read(downloadServiceFactoryProvider)();
    try {
      final created =
          await service.createCollectionDirectory(libraryPath, name);
      await ref.read(novelRepositoryProvider).upsert(
            NovelMetadata(
              siteType: 'web',
              novelId: created.novelId,
              title: name,
              url: '',
              folderName: created.folderName,
              episodeCount: 0,
              downloadedAt: DateTime.now(),
            ),
          );
      ref.invalidate(allNovelsProvider);
    } finally {
      service.dispose();
    }
  }

  /// Re-downloads the novel identified by [folderName].
  ///
  /// [parentPath] is the directory that physically contains the novel folder
  /// (i.e. `dirname` of the novel folder's path). The re-download targets this
  /// location so a novel stored inside an organizational subfolder is updated
  /// in place rather than being duplicated at the library root. The caller
  /// (which already holds the novel folder's physical path) is responsible for
  /// supplying it.
  Future<void> refreshNovel(
    String folderName, {
    required String parentPath,
  }) async {
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

      await startDownload(
        url: Uri.parse(metadata.url),
        outputPath: parentPath,
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

final downloadProvider = NotifierProvider<DownloadNotifier, DownloadState>(
  DownloadNotifier.new,
);

final novelSiteRegistryProvider = Provider<NovelSiteRegistry>((ref) {
  return NovelSiteRegistry();
});

/// Factory for [DownloadService] instances. A new service is created per
/// download (each owns an `http.Client` it disposes when done). Exposed as a
/// provider so tests can inject a fake without performing real network I/O.
final downloadServiceFactoryProvider = Provider<DownloadService Function()>(
  (ref) => DownloadService.new,
);
