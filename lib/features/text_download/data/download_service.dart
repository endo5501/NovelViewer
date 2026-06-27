import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/episode_cache/domain/episode_cache.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';
import 'package:novel_viewer/shared/utils/file_name_utils.dart' as file_names;

typedef ProgressCallback = void Function(
    int current, int total, int skipped, int failed);

final _log = Logger('text_download');

const _maxIndexPages = 100;

/// Re-exported from the shared name utilities so existing call sites and tests
/// keep working while the sanitiser lives in one place.
String safeName(String name) => file_names.safeName(name);

String formatEpisodeFileName(int index, String title, int totalEpisodes) {
  final padWidth = totalEpisodes.toString().length;
  final paddedIndex = index.toString().padLeft(padWidth, '0');
  final safeTitle = safeName(title);
  return '${paddedIndex}_$safeTitle.txt';
}

/// Fixed zero-pad width for generic-web collection episode files. Unlike
/// [formatEpisodeFileName] (whose width tracks the total episode count), a
/// collection grows one article at a time, so a dynamic width would rename
/// existing files whenever the count crosses a power-of-ten boundary (D7).
const int collectionEpisodePadWidth = 4;

/// Episode file name for a generic-web collection: a fixed-width zero-padded
/// index plus the sanitised article title. Stable as the collection grows.
String formatCollectionEpisodeFileName(int index, String title) {
  final paddedIndex = index.toString().padLeft(collectionEpisodePadWidth, '0');
  final safeTitle = safeName(title);
  return '${paddedIndex}_$safeTitle.txt';
}

/// Outcome of [DownloadService.createCollectionDirectory]: the created
/// directory together with the folder name and the novel id derived from the
/// (possibly suffixed) collection name.
class CollectionDirectory {
  final Directory dir;
  final String folderName;
  final String novelId;

  const CollectionDirectory({
    required this.dir,
    required this.folderName,
    required this.novelId,
  });
}

/// An article fetched and extracted for a collection: its title, body text, and
/// the source page's `Last-Modified` (if any).
class FetchedArticle {
  final String title;
  final String body;
  final String? lastModified;

  const FetchedArticle({
    required this.title,
    required this.body,
    required this.lastModified,
  });
}

/// Outcome of [DownloadService.downloadArticleIntoCollection].
class CollectionAppendResult {
  final String title;
  final int episodeIndex;

  /// True when an existing episode (same URL) was updated rather than appended.
  final bool updated;

  const CollectionAppendResult({
    required this.title,
    required this.episodeIndex,
    required this.updated,
  });
}

/// Matches an episode file name `{paddedIndex}_{safeTitle}.txt`, capturing the
/// numeric (zero-padded) index and the rest of the name (the safe title). The
/// title group is `(.*)` (not `(.+)`) so files with an empty sanitised title
/// (`01_.txt`, produced when `safeName(title)` is empty) are still matched.
final RegExp _episodeFileNamePattern = RegExp(r'^(\d+)_(.*)\.txt$');

/// Migrates existing episode files in [directory] to the zero-pad width implied
/// by [totalEpisodes], so that crossing a power-of-ten boundary (e.g. 99 -> 100)
/// does not cause a spurious full re-download or leave old-width files behind
/// (F104).
///
/// The pad width of [formatEpisodeFileName] depends on the digit count of the
/// current total episode count, so when the total grows/shrinks across a
/// boundary every episode's expected file name changes (`01_` <-> `001_`).
/// [DownloadService._canSkipEpisode] recomputes the file name with the *current*
/// total, so without this migration it would not find the existing (old-width)
/// files and would re-download everything, leaving the old files as garbage.
///
/// For each episode in the current index, this finds an existing file that
/// represents the same episode at a different pad width (same parsed index and
/// same `safeName(title)`, but a different file name) and:
/// - renames it to the current-width name when that name does not yet exist;
/// - deletes it (residual garbage) when the current-width name already exists.
/// It never touches the canonical current-width file, is idempotent, handles
/// both width increase and decrease, and does not modify the episode cache.
/// Individual rename/delete failures are logged and skipped (that episode falls
/// back to being re-downloaded) rather than aborting the whole download.
Future<void> migrateEpisodeFileNamePadding({
  required Directory directory,
  required List<({int index, String title})> episodes,
  required int totalEpisodes,
}) async {
  if (!directory.existsSync()) return;

  // Index existing .txt files by (parsedIndex, restName); a given key may have
  // more than one file when corruption left differently-padded duplicates.
  final byKey = <String, List<String>>{};
  final List<FileSystemEntity> entries;
  try {
    entries = directory.listSync(followLinks: false);
  } catch (e, st) {
    // Listing failed (permissions, symlink loop, ...). Honour the no-abort
    // contract: skip migration rather than failing the whole download; the
    // affected episodes fall back to the legacy re-download behaviour.
    _log.warning(
      'Failed to list ${directory.path} for pad-width migration; skipping',
      e,
      st,
    );
    return;
  }
  for (final entity in entries) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    final match = _episodeFileNamePattern.firstMatch(name);
    if (match == null) continue;
    final parsedIndex = int.parse(match.group(1)!);
    final restName = match.group(2)!;
    (byKey['$parsedIndex/$restName'] ??= <String>[]).add(name);
  }

  for (final episode in episodes) {
    final newName = formatEpisodeFileName(episode.index, episode.title, totalEpisodes);
    final matches = byKey['${episode.index}/${safeName(episode.title)}'];
    if (matches == null) continue;

    for (final existing in matches) {
      // Never delete or overwrite the canonical current-width file.
      if (existing == newName) continue;
      final existingFile = File('${directory.path}/$existing');
      final target = File('${directory.path}/$newName');
      try {
        if (target.existsSync()) {
          // Residual garbage: a correct file already exists, drop the stale one.
          existingFile.deleteSync();
        } else {
          // Migrate the old-width file to the current-width name.
          existingFile.renameSync(target.path);
        }
      } catch (e, st) {
        _log.warning(
          'Failed to migrate episode file "$existing" -> "$newName" in ${directory.path}',
          e,
          st,
        );
      }
    }
  }
}

/// Thrown when the first index page is fetched successfully but parses to no
/// usable content — an empty `episodes` list AND a null `bodyContent` (F118).
///
/// This is the signature of site markup drift (the adapter's selectors no longer
/// match), not a legitimate empty novel. It is thrown before any novel folder is
/// created so no empty folder is left on disk, and propagates to the caller to be
/// surfaced as a download error (the same severity as a failed first index
/// fetch) instead of silently "completing" with `episodeCount == 0`.
///
/// Short stories and Aozora Bunko pages populate `bodyContent`, so they do not
/// satisfy this condition and are unaffected.
class EmptyIndexException implements Exception {
  final Uri url;

  const EmptyIndexException(this.url);

  @override
  String toString() =>
      'EmptyIndexException: index page parsed to no episodes and no body '
      'content (likely site markup drift): $url';
}

class DownloadResult {
  final String siteType;
  final String novelId;
  final String title;
  final String folderName;
  final int episodeCount;
  final int skippedCount;
  final int failedCount;

  /// True when the table of contents could not be fully fetched because a
  /// subsequent index page failed to fetch or parse (F102). The episodes that
  /// were collected before the failure are still downloaded, but some episodes
  /// may be missing. Defaults to false (a fully-fetched index, including one
  /// that stopped only because of the 100-page guard).
  final bool indexTruncated;
  final Uri url;

  const DownloadResult({
    required this.siteType,
    required this.novelId,
    required this.title,
    required this.folderName,
    required this.episodeCount,
    this.skippedCount = 0,
    this.failedCount = 0,
    this.indexTruncated = false,
    required this.url,
  });
}

/// Internal result of collecting a (possibly multi-page) index: the merged
/// index plus whether the pagination chain was truncated by a fetch/parse
/// failure.
class _CollectedIndex {
  final NovelIndex index;
  final bool truncated;

  const _CollectedIndex(this.index, {this.truncated = false});
}

class DownloadService {
  final http.Client _client;
  final Duration requestDelay;

  /// Per-request timeout applied to every HTTP GET. Without it a stuck
  /// connection would hang the whole download forever (F103). On timeout the
  /// request throws [TimeoutException], which is then handled like any other
  /// fetch failure (episode -> failedCount, later index page -> indexTruncated,
  /// first index page -> propagated to the caller).
  final Duration requestTimeout;

  /// Maximum number of *retries* (in addition to the initial attempt) applied by
  /// [_fetchPageResponse] to transient fetch failures — HTTP 5xx and
  /// [TimeoutException] only (F121). The total number of attempts is therefore
  /// `maxRetries + 1`. Permanent failures (HTTP 4xx) and non-transient
  /// exceptions are never retried.
  final int maxRetries;

  /// Base delay for the exponential backoff between retries. The wait before the
  /// n-th retry (1-based) is `retryBaseDelay * 2^(n-1)`. Injectable so tests can
  /// exercise the retry path without waiting in real time.
  final Duration retryBaseDelay;

  DownloadService({
    http.Client? client,
    this.requestDelay = const Duration(milliseconds: 700),
    this.requestTimeout = const Duration(seconds: 30),
    this.maxRetries = 2,
    this.retryBaseDelay = const Duration(milliseconds: 500),
  }) : _client = client ?? http.Client();

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// True when [statusCode] denotes a transient server-side failure (HTTP 5xx)
  /// that is worth retrying. HTTP 4xx (e.g. 404 not found, 403 blocked) is a
  /// permanent failure and is never retried.
  static bool _isTransientStatus(int statusCode) =>
      statusCode >= 500 && statusCode <= 599;

  /// Waits for the exponential backoff before the [attempt]-th retry (1-based),
  /// cooperating with cancellation. [Future.delayed] itself is not interruptible,
  /// so a cancellation requested during the wait is observed right after it (the
  /// post-wait [CancellationToken.throwIfCancelled] throws [CancelledException]),
  /// bounded by a single backoff interval — the cancellation is never lost or
  /// misclassified, just deferred by at most one wait.
  Future<void> _backoff(int attempt, CancellationToken? cancelToken) async {
    cancelToken?.throwIfCancelled();
    await Future.delayed(retryBaseDelay * (1 << (attempt - 1)));
    cancelToken?.throwIfCancelled();
  }

  /// Fetches [url] with the configured timeout, retrying transient failures
  /// (HTTP 5xx and [TimeoutException] only) up to [maxRetries] times with
  /// exponential backoff (F121).
  ///
  /// - HTTP 200 is returned immediately.
  /// - HTTP 4xx (and any other non-200, non-5xx status) is a permanent failure:
  ///   it is thrown as [HttpException] without retrying.
  /// - HTTP 5xx and [TimeoutException] are retried; once retries are exhausted
  ///   the last failure surfaces (HttpException / rethrown TimeoutException),
  ///   preserving the per-caller contract (episode -> failedCount, later index
  ///   page -> indexTruncated, first index page -> propagated).
  /// - Other exceptions (e.g. [http.ClientException] from a cancelled client)
  ///   are NOT retried and propagate, so a cancellation is never mistaken for a
  ///   transient failure.
  Future<http.Response> _fetchPageResponse(
    Uri url, {
    NovelSite? site,
    CancellationToken? cancelToken,
  }) async {
    final siteHeaders = site?.requestHeaders(url) ?? const <String, String>{};
    final headers = {'User-Agent': _userAgent, ...siteHeaders};

    var attempt = 0;
    while (true) {
      // Guard before each attempt so a cancellation (which closed the client)
      // is not retried into a fresh ClientException.
      cancelToken?.throwIfCancelled();
      try {
        final response =
            await _client.get(url, headers: headers).timeout(requestTimeout);
        if (response.statusCode == 200) return response;
        if (_isTransientStatus(response.statusCode) && attempt < maxRetries) {
          attempt++;
          await _backoff(attempt, cancelToken);
          continue;
        }
        throw HttpException('HTTP ${response.statusCode}', uri: url);
      } on TimeoutException {
        if (attempt < maxRetries) {
          cancelToken?.throwIfCancelled();
          attempt++;
          await _backoff(attempt, cancelToken);
          continue;
        }
        rethrow;
      }
    }
  }

  Future<Directory> createNovelDirectory(
    String parentPath,
    String folderName,
  ) async {
    final dir = Directory('$parentPath/$folderName');
    await dir.create(recursive: true);
    return dir;
  }

  String buildFolderName(NovelSite site, Uri url) {
    final novelId = site.extractNovelId(url);
    return '${site.siteType}_$novelId';
  }

  Future<void> saveEpisode({
    required Directory directory,
    required int index,
    required String title,
    required String content,
    required int totalEpisodes,
  }) async {
    final fileName = formatEpisodeFileName(index, title, totalEpisodes);
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);
  }

  bool _shouldDownload(String? cachedLastModified, String? updatedAt) {
    if (cachedLastModified == null || updatedAt == null) return true;
    return updatedAt != cachedLastModified;
  }

  Future<DownloadResult> downloadNovel({
    required NovelSite site,
    required Uri url,
    required String outputPath,
    EpisodeCacheRepository? episodeCacheRepository,
    ProgressCallback? onProgress,
    CancellationToken? cancelToken,
  }) async {
    // When cancelled, abort the in-flight request by closing the client. The
    // episodes saved before cancellation are intentionally left in place so the
    // download can be resumed (cache hit) on a later run.
    cancelToken?.onCancel(_client.close);

    cancelToken?.throwIfCancelled();
    final normalizedUrl = site.normalizeUrl(url);
    final folderName = buildFolderName(site, normalizedUrl);
    final novelId = site.extractNovelId(normalizedUrl);
    final indexResponse = await _fetchPageResponse(
      normalizedUrl,
      site: site,
      cancelToken: cancelToken,
    );
    final novelIndex = site.parseIndex(
      site.decodeBody(indexResponse),
      normalizedUrl,
    );

    // F118: the index was fetched (HTTP 200) but parsed to nothing usable — no
    // episodes AND no body content. This is markup drift, not a real empty
    // novel. Throw BEFORE creating the folder so no empty directory is left on
    // disk, and let it propagate to the caller as a download error instead of
    // silently "completing" with episodeCount=0. Short stories / Aozora set
    // bodyContent, so they do not hit this guard.
    if (novelIndex.episodes.isEmpty && novelIndex.bodyContent == null) {
      _log.warning(
          'Index page parsed to no episodes and no body content (likely site '
          'markup drift): $normalizedUrl');
      throw EmptyIndexException(normalizedUrl);
    }

    final dir = await createNovelDirectory(outputPath, folderName);

    // Short story: no episodes but body content available
    if (novelIndex.episodes.isEmpty && novelIndex.bodyContent != null) {
      return _downloadShortStory(
        site: site,
        url: normalizedUrl,
        novelId: novelId,
        novelIndex: novelIndex,
        folderName: folderName,
        dir: dir,
        episodeCacheRepository: episodeCacheRepository,
        onProgress: onProgress,
        indexLastModified: indexResponse.headers['last-modified'],
        cancelToken: cancelToken,
      );
    }

    final collected = await _collectPagedIndex(
      site: site,
      firstIndex: novelIndex,
      firstUrl: normalizedUrl,
      cancelToken: cancelToken,
    );

    return _downloadEpisodes(
      site: site,
      url: normalizedUrl,
      novelId: novelId,
      novelIndex: collected.index,
      folderName: folderName,
      dir: dir,
      episodeCacheRepository: episodeCacheRepository,
      onProgress: onProgress,
      indexTruncated: collected.truncated,
      cancelToken: cancelToken,
    );
  }

  Future<_CollectedIndex> _collectPagedIndex({
    required NovelSite site,
    required NovelIndex firstIndex,
    required Uri firstUrl,
    CancellationToken? cancelToken,
  }) async {
    final episodes = <Episode>[];
    final seenEpisodeUrls = <String>{};
    final visitedIndexUrls = <String>{firstUrl.toString()};

    void addEpisodes(Iterable<Episode> items) {
      for (final e in items) {
        if (seenEpisodeUrls.add(e.url.toString())) episodes.add(e);
      }
    }

    addEpisodes(firstIndex.episodes);

    var next = firstIndex.nextPageUrl;
    var pageCount = 1;
    var truncated = false;

    while (next != null && pageCount < _maxIndexPages) {
      // Checked before the try so a cancellation propagates instead of being
      // mistaken for an index fetch failure (truncation).
      cancelToken?.throwIfCancelled();
      final key = next.toString();
      if (!visitedIndexUrls.add(key)) break;

      await Future.delayed(requestDelay);
      try {
        final res = await _fetchPageResponse(
          next,
          site: site,
          cancelToken: cancelToken,
        );
        final idx = site.parseIndex(site.decodeBody(res), next);
        addEpisodes(idx.episodes);
        next = idx.nextPageUrl;
        pageCount++;
      } catch (e, st) {
        // If the failure was caused by a cancellation closing the client, treat
        // it as a cancellation (not a truncation).
        cancelToken?.throwIfCancelled();
        // A later index page failed to fetch/parse. Do not swallow this
        // silently (F102): stop the chain, keep the episodes collected so far,
        // and flag the result as truncated so the UI can warn the user that
        // some episodes may be missing.
        _log.warning('Failed to fetch index page $next; index truncated', e, st);
        truncated = true;
        break;
      }
    }

    final reindexed = [
      for (final (i, e) in episodes.indexed)
        Episode(
          index: i + 1,
          title: e.title,
          url: e.url,
          updatedAt: e.updatedAt,
        ),
    ];

    return _CollectedIndex(
      NovelIndex(
        title: firstIndex.title,
        episodes: reindexed,
        bodyContent: firstIndex.bodyContent,
      ),
      truncated: truncated,
    );
  }

  Future<DownloadResult> _downloadShortStory({
    required NovelSite site,
    required Uri url,
    required String novelId,
    required NovelIndex novelIndex,
    required String folderName,
    required Directory dir,
    EpisodeCacheRepository? episodeCacheRepository,
    ProgressCallback? onProgress,
    String? indexLastModified,
    CancellationToken? cancelToken,
  }) async {
    // The index fetch already happened; honour a cancellation requested during
    // it before doing any local save/cache work.
    cancelToken?.throwIfCancelled();

    final cache = episodeCacheRepository != null
        ? await episodeCacheRepository.getAllAsMap()
        : <String, EpisodeCache>{};

    // Check if we can skip this short story
    final canSkip = _canSkipEpisode(
      url: url,
      index: 1,
      title: novelIndex.title,
      updatedAt: indexLastModified,
      totalEpisodes: 1,
      dir: dir,
      cache: cache,
    );

    final skippedCount = canSkip ? 1 : 0;

    if (!canSkip) {
      await _saveAndCacheEpisode(
        url: url,
        index: 1,
        title: novelIndex.title,
        content: novelIndex.bodyContent!,
        updatedAt: indexLastModified,
        totalEpisodes: 1,
        dir: dir,
        episodeCacheRepository: episodeCacheRepository,
      );
    }

    onProgress?.call(1, 1, skippedCount, 0);

    return DownloadResult(
      siteType: site.siteType,
      novelId: novelId,
      title: novelIndex.title,
      folderName: folderName,
      episodeCount: 1,
      skippedCount: skippedCount,
      url: url,
    );
  }

  Future<DownloadResult> _downloadEpisodes({
    required NovelSite site,
    required Uri url,
    required String novelId,
    required NovelIndex novelIndex,
    required String folderName,
    required Directory dir,
    EpisodeCacheRepository? episodeCacheRepository,
    ProgressCallback? onProgress,
    bool indexTruncated = false,
    CancellationToken? cancelToken,
  }) async {
    final total = novelIndex.episodes.length;

    // Before the skip/download loop, align any existing episode files to the
    // current zero-pad width so crossing a power-of-ten boundary (e.g. 99->100)
    // does not trigger a spurious full re-download or leave old-width files
    // behind (F104). Uses the merged index total (= the new pad width).
    await migrateEpisodeFileNamePadding(
      directory: dir,
      episodes: [
        for (final e in novelIndex.episodes) (index: e.index, title: e.title),
      ],
      totalEpisodes: total,
    );

    final cache = episodeCacheRepository != null
        ? await episodeCacheRepository.getAllAsMap()
        : <String, EpisodeCache>{};

    var skippedCount = 0;
    var failedCount = 0;
    var hadPriorRequest = false;

    for (final (i, episode) in novelIndex.episodes.indexed) {
      // Checked outside the per-episode try so a cancellation propagates rather
      // than being counted as a failed episode.
      cancelToken?.throwIfCancelled();

      // Check skip condition first (local only, no network)
      final canSkip = _canSkipEpisode(
        url: episode.url,
        index: episode.index,
        title: episode.title,
        updatedAt: episode.updatedAt,
        totalEpisodes: total,
        dir: dir,
        cache: cache,
      );

      if (canSkip) {
        skippedCount++;
      } else {
        if (hadPriorRequest) {
          await Future.delayed(requestDelay);
        }
        try {
          final response = await _fetchPageResponse(
            episode.url,
            site: site,
            cancelToken: cancelToken,
          );
          final content = site.parseEpisode(site.decodeBody(response));
          if (content.trim().isEmpty) {
            // The page was fetched but yielded no body text. This happens when
            // the site changes its markup and the adapter's selectors no longer
            // match (the adapters return ''). Saving/caching it would persist an
            // empty file and skip the episode forever on later updates, so treat
            // it as a failure instead and leave the cache untouched for retry.
            failedCount++;
            _log.warning(
                'Empty parse result for episode ${episode.index} from ${episode.url}; treated as failure (not saved or cached)');
          } else {
            await _saveAndCacheEpisode(
              url: episode.url,
              index: episode.index,
              title: episode.title,
              content: content,
              updatedAt: episode.updatedAt,
              totalEpisodes: total,
              dir: dir,
              episodeCacheRepository: episodeCacheRepository,
            );
          }
        } catch (e, st) {
          // If the failure was caused by a cancellation closing the client,
          // treat it as a cancellation (not a failed episode).
          cancelToken?.throwIfCancelled();
          failedCount++;
          _log.warning(
              'Failed to download episode ${episode.index} from ${episode.url}',
              e,
              st);
        }
        hadPriorRequest = true;
      }

      onProgress?.call(i + 1, total, skippedCount, failedCount);
    }

    return DownloadResult(
      siteType: site.siteType,
      novelId: novelId,
      title: novelIndex.title,
      folderName: folderName,
      episodeCount: total,
      skippedCount: skippedCount,
      failedCount: failedCount,
      indexTruncated: indexTruncated,
      url: url,
    );
  }

  bool _canSkipEpisode({
    required Uri url,
    required int index,
    required String title,
    String? updatedAt,
    required int totalEpisodes,
    required Directory dir,
    Map<String, EpisodeCache>? cache,
  }) {
    final cached = cache?[url.toString()];
    if (cached == null) return false;
    final fileName = formatEpisodeFileName(index, title, totalEpisodes);
    final localFile = File('${dir.path}/$fileName');
    if (!localFile.existsSync()) return false;
    return !_shouldDownload(cached.lastModified, updatedAt);
  }

  Future<void> _saveAndCacheEpisode({
    required Uri url,
    required int index,
    required String title,
    required String content,
    String? updatedAt,
    required int totalEpisodes,
    required Directory dir,
    EpisodeCacheRepository? episodeCacheRepository,
  }) async {
    await saveEpisode(
      directory: dir,
      index: index,
      title: title,
      content: content,
      totalEpisodes: totalEpisodes,
    );
    await episodeCacheRepository?.upsert(EpisodeCache(
      url: url.toString(),
      episodeIndex: index,
      title: title,
      lastModified: updatedAt,
      downloadedAt: DateTime.now(),
    ));
  }

  /// Creates a new generic-web collection folder `web_<slug>` under
  /// [outputPath]. The slug is [name] sanitised for the filesystem; if the
  /// folder already exists a `_2`, `_3`, … suffix is appended so each call
  /// yields a fresh collection. The returned [CollectionDirectory] carries the
  /// final folder name and the matching novel id (folder name without `web_`).
  Future<CollectionDirectory> createCollectionDirectory(
    String outputPath,
    String name,
  ) async {
    final baseId = safeName(name);
    var novelId = baseId;
    var folderName = 'web_$novelId';
    var dir = Directory('$outputPath/$folderName');
    var suffix = 2;
    while (dir.existsSync()) {
      novelId = '${baseId}_$suffix';
      folderName = 'web_$novelId';
      dir = Directory('$outputPath/$folderName');
      suffix++;
    }
    await dir.create(recursive: true);
    return CollectionDirectory(
      dir: dir,
      folderName: folderName,
      novelId: novelId,
    );
  }

  /// Fetches [url] via [site], extracts the article body, and saves it into the
  /// existing [collectionDir] as an episode. The article identity is the URL,
  /// tracked in the folder's [episodeCacheRepository]:
  /// - a URL already in the collection updates its existing episode in place
  ///   (no duplicate); the old file is replaced even if the title changed;
  /// - a new URL is appended at `max(existing index) + 1`.
  ///
  /// Throws [EmptyIndexException] (and saves nothing) when the page yields no
  /// usable body — the same guard the specialized download path uses, so a
  /// JS-rendered or mis-typed page does not leave an empty episode behind.
  Future<CollectionAppendResult> downloadArticleIntoCollection({
    required NovelSite site,
    required Uri url,
    required Directory collectionDir,
    required EpisodeCacheRepository episodeCacheRepository,
    CancellationToken? cancelToken,
  }) async {
    final normalizedUrl = site.normalizeUrl(url);
    final article = await fetchArticle(
      site: site,
      url: normalizedUrl,
      cancelToken: cancelToken,
    );
    return saveArticleToCollection(
      collectionDir: collectionDir,
      url: normalizedUrl,
      article: article,
      episodeCacheRepository: episodeCacheRepository,
    );
  }

  /// Fetches [url] via [site] and extracts the article (title + body). Throws
  /// [EmptyIndexException] when no usable body is produced (empty / JS-rendered
  /// / mis-typed page), so callers never persist an empty article. Exposed
  /// separately so a "new collection" flow can name the folder after the
  /// article title before any folder is created.
  Future<FetchedArticle> fetchArticle({
    required NovelSite site,
    required Uri url,
    CancellationToken? cancelToken,
  }) async {
    cancelToken?.onCancel(_client.close);
    cancelToken?.throwIfCancelled();

    final normalizedUrl = site.normalizeUrl(url);
    final response = await _fetchPageResponse(
      normalizedUrl,
      site: site,
      cancelToken: cancelToken,
    );
    final index = site.parseIndex(site.decodeBody(response), normalizedUrl);
    final body = index.bodyContent;
    if (body == null || body.trim().isEmpty) {
      throw EmptyIndexException(normalizedUrl);
    }
    return FetchedArticle(
      title: index.title,
      body: body,
      lastModified: response.headers['last-modified'],
    );
  }

  /// Saves a pre-fetched [article] into [collectionDir] as an episode, indexing
  /// it by [url] in the folder's [episodeCacheRepository] (update existing URL
  /// in place, otherwise append at max+1). See [downloadArticleIntoCollection].
  Future<CollectionAppendResult> saveArticleToCollection({
    required Directory collectionDir,
    required Uri url,
    required FetchedArticle article,
    required EpisodeCacheRepository episodeCacheRepository,
  }) async {
    final cache = await episodeCacheRepository.getAllAsMap();
    final existing = cache[url.toString()];
    final int episodeIndex;
    final bool updated;
    if (existing != null) {
      episodeIndex = existing.episodeIndex;
      updated = true;
    } else {
      var maxIndex = 0;
      for (final entry in cache.values) {
        if (entry.episodeIndex > maxIndex) maxIndex = entry.episodeIndex;
      }
      episodeIndex = maxIndex + 1;
      updated = false;
    }

    // Remove any existing file(s) for this index so a changed title does not
    // leave an orphan; the fresh file is written below.
    _removeCollectionEpisodeFiles(collectionDir, episodeIndex);

    final fileName = formatCollectionEpisodeFileName(episodeIndex, article.title);
    await File('${collectionDir.path}/$fileName').writeAsString(article.body);

    await episodeCacheRepository.upsert(EpisodeCache(
      url: url.toString(),
      episodeIndex: episodeIndex,
      title: article.title,
      lastModified: article.lastModified,
      downloadedAt: DateTime.now(),
    ));

    return CollectionAppendResult(
      title: article.title,
      episodeIndex: episodeIndex,
      updated: updated,
    );
  }

  /// Deletes every `{paddedIndex}_*.txt` file in [dir] whose parsed index equals
  /// [index] (any title), used before re-writing a collection episode.
  void _removeCollectionEpisodeFiles(Directory dir, int index) {
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final match = _episodeFileNamePattern.firstMatch(name);
      if (match == null) continue;
      if (int.parse(match.group(1)!) != index) continue;
      try {
        entity.deleteSync();
      } catch (e, st) {
        _log.warning('Failed to remove stale collection file "$name"', e, st);
      }
    }
  }

  void dispose() {
    _client.close();
  }
}
