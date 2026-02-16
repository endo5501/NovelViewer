import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/episode_cache/domain/episode_cache.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

typedef ProgressCallback = void Function(int current, int total, int skipped);

const _maxIndexPages = 100;

final _invalidChars = RegExp(r'[\\/:*?"<>|]');
final _multipleSpaces = RegExp(r'\s+');

String safeName(String name) {
  return name
      .replaceAll(_invalidChars, '_')
      .replaceAll(_multipleSpaces, ' ')
      .trim();
}

String formatEpisodeFileName(int index, String title, int totalEpisodes) {
  final padWidth = totalEpisodes.toString().length;
  final paddedIndex = index.toString().padLeft(padWidth, '0');
  final safeTitle = safeName(title);
  return '${paddedIndex}_$safeTitle.txt';
}

class DownloadResult {
  final String siteType;
  final String novelId;
  final String title;
  final String folderName;
  final int episodeCount;
  final int skippedCount;
  final Uri url;

  const DownloadResult({
    required this.siteType,
    required this.novelId,
    required this.title,
    required this.folderName,
    required this.episodeCount,
    this.skippedCount = 0,
    required this.url,
  });
}

class DownloadService {
  final http.Client _client;
  final Duration requestDelay;

  DownloadService({
    http.Client? client,
    this.requestDelay = const Duration(milliseconds: 700),
  }) : _client = client ?? http.Client();

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  Future<http.Response> _fetchPageResponse(Uri url) async {
    final response = await _client.get(
      url,
      headers: {'User-Agent': _userAgent},
    );
    if (response.statusCode != 200) {
      throw HttpException(
        'HTTP ${response.statusCode}',
        uri: url,
      );
    }
    return response;
  }

  Future<String> fetchPage(Uri url) async {
    final response = await _fetchPageResponse(url);
    return response.body;
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
  }) async {
    final normalizedUrl = site.normalizeUrl(url);
    final folderName = buildFolderName(site, normalizedUrl);
    final novelId = site.extractNovelId(normalizedUrl);
    final indexResponse = await _fetchPageResponse(normalizedUrl);
    final novelIndex = site.parseIndex(indexResponse.body, normalizedUrl);

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
      );
    }

    final mergedIndex = await _collectPagedIndex(
      site: site,
      firstIndex: novelIndex,
      firstUrl: normalizedUrl,
    );

    return _downloadEpisodes(
      site: site,
      url: normalizedUrl,
      novelId: novelId,
      novelIndex: mergedIndex,
      folderName: folderName,
      dir: dir,
      episodeCacheRepository: episodeCacheRepository,
      onProgress: onProgress,
    );
  }

  Future<NovelIndex> _collectPagedIndex({
    required NovelSite site,
    required NovelIndex firstIndex,
    required Uri firstUrl,
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

    while (next != null && pageCount < _maxIndexPages) {
      final key = next.toString();
      if (!visitedIndexUrls.add(key)) break;

      await Future.delayed(requestDelay);
      try {
        final res = await _fetchPageResponse(next);
        final idx = site.parseIndex(res.body, next);
        addEpisodes(idx.episodes);
        next = idx.nextPageUrl;
        pageCount++;
      } catch (_) {
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

    return NovelIndex(
      title: firstIndex.title,
      episodes: reindexed,
      bodyContent: firstIndex.bodyContent,
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
  }) async {
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

    onProgress?.call(1, 1, skippedCount);

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
  }) async {
    final total = novelIndex.episodes.length;
    final cache = episodeCacheRepository != null
        ? await episodeCacheRepository.getAllAsMap()
        : <String, EpisodeCache>{};

    var skippedCount = 0;
    var hadPriorRequest = false;

    for (final (i, episode) in novelIndex.episodes.indexed) {
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
          final response = await _fetchPageResponse(episode.url);
          final content = site.parseEpisode(response.body);
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
        } catch (e) {
          // Skip failed episodes and continue
        }
        hadPriorRequest = true;
      }

      onProgress?.call(i + 1, total, skippedCount);
    }

    return DownloadResult(
      siteType: site.siteType,
      novelId: novelId,
      title: novelIndex.title,
      folderName: folderName,
      episodeCount: total,
      skippedCount: skippedCount,
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

  void dispose() {
    _client.close();
  }
}
