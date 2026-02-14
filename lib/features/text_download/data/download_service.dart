import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/episode_cache/domain/episode_cache.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

typedef ProgressCallback = void Function(int current, int total, int skipped);

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

  Future<Map<String, String>?> fetchHead(Uri url) async {
    try {
      final response = await _client.head(
        url,
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode != 200) return null;
      return response.headers;
    } catch (_) {
      return null;
    }
  }

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

  bool _shouldDownload(String? cachedLastModified, String? serverLastModified) {
    if (serverLastModified == null) return false;
    if (cachedLastModified == null) return true;
    return serverLastModified != cachedLastModified;
  }

  Future<DownloadResult> downloadNovel({
    required NovelSite site,
    required Uri url,
    required String outputPath,
    EpisodeCacheRepository? episodeCacheRepository,
    ProgressCallback? onProgress,
  }) async {
    final folderName = buildFolderName(site, url);
    final novelId = site.extractNovelId(url);
    final indexResponse = await _fetchPageResponse(url);
    final novelIndex = site.parseIndex(indexResponse.body, url);

    final dir = await createNovelDirectory(outputPath, folderName);

    // Short story: no episodes but body content available
    if (novelIndex.episodes.isEmpty && novelIndex.bodyContent != null) {
      return _downloadShortStory(
        site: site,
        url: url,
        novelId: novelId,
        novelIndex: novelIndex,
        folderName: folderName,
        dir: dir,
        episodeCacheRepository: episodeCacheRepository,
        onProgress: onProgress,
        indexLastModified: indexResponse.headers['last-modified'],
      );
    }

    return _downloadEpisodes(
      site: site,
      url: url,
      novelId: novelId,
      novelIndex: novelIndex,
      folderName: folderName,
      dir: dir,
      episodeCacheRepository: episodeCacheRepository,
      onProgress: onProgress,
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

    final skipped = await _downloadSingleEpisode(
      url: url,
      index: 1,
      title: novelIndex.title,
      content: novelIndex.bodyContent!,
      contentLastModified: indexLastModified,
      totalEpisodes: 1,
      dir: dir,
      episodeCacheRepository: episodeCacheRepository,
      fetchContent: null,
      cache: cache,
    );

    final skippedCount = skipped ? 1 : 0;
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

    for (final (i, episode) in novelIndex.episodes.indexed) {
      if (i > 0) {
        await Future.delayed(requestDelay);
      }

      try {
        final skipped = await _downloadSingleEpisode(
          url: episode.url,
          index: episode.index,
          title: episode.title,
          content: null,
          totalEpisodes: total,
          dir: dir,
          episodeCacheRepository: episodeCacheRepository,
          fetchContent: () async {
            final response = await _fetchPageResponse(episode.url);
            return (site.parseEpisode(response.body), response.headers['last-modified']);
          },
          cache: cache,
        );

        if (skipped) skippedCount++;
      } catch (e) {
        // Skip failed episodes and continue
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

  Future<bool> _downloadSingleEpisode({
    required Uri url,
    required int index,
    required String title,
    required String? content,
    String? contentLastModified,
    required int totalEpisodes,
    required Directory dir,
    EpisodeCacheRepository? episodeCacheRepository,
    required Future<(String, String?)> Function()? fetchContent,
    Map<String, EpisodeCache>? cache,
  }) async {
    final urlStr = url.toString();
    final cached = cache?[urlStr];

    // Check if episode can be skipped
    if (cached != null) {
      final fileName = formatEpisodeFileName(index, title, totalEpisodes);
      final localFile = File('${dir.path}/$fileName');
      if (localFile.existsSync()) {
        final headers = await fetchHead(url);
        final serverLastModified = headers?['last-modified'];
        if (!_shouldDownload(cached.lastModified, serverLastModified)) {
          return true; // Skipped
        }
      }
    }

    // Fetch content if not provided
    String episodeContent;
    String? lastModified;
    if (content != null) {
      episodeContent = content;
      lastModified = contentLastModified;
    } else if (fetchContent != null) {
      (episodeContent, lastModified) = await fetchContent();
    } else {
      throw ArgumentError('Either content or fetchContent must be provided');
    }

    // Save episode
    await saveEpisode(
      directory: dir,
      index: index,
      title: title,
      content: episodeContent,
      totalEpisodes: totalEpisodes,
    );

    // Update cache
    if (episodeCacheRepository != null) {
      await episodeCacheRepository.upsert(EpisodeCache(
        url: urlStr,
        episodeIndex: index,
        title: title,
        lastModified: lastModified,
        downloadedAt: DateTime.now(),
      ));
    }

    return false; // Not skipped
  }

  void dispose() {
    _client.close();
  }
}
