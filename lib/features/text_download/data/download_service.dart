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
    final indexHtml = await fetchPage(url);
    final novelIndex = site.parseIndex(indexHtml, url);

    final dir = await createNovelDirectory(outputPath, folderName);
    final total = novelIndex.episodes.length;
    var skippedCount = 0;

    final cache = episodeCacheRepository != null
        ? await episodeCacheRepository.getAllAsMap()
        : <String, EpisodeCache>{};

    for (final (i, episode) in novelIndex.episodes.indexed) {
      try {
        if (i > 0) {
          await Future.delayed(requestDelay);
        }

        final urlStr = episode.url.toString();
        final cached = cache[urlStr];

        if (cached != null) {
          final fileName = formatEpisodeFileName(episode.index, episode.title, total);
          final localFile = File('${dir.path}/$fileName');
          if (localFile.existsSync()) {
            final headers = await fetchHead(episode.url);
            final serverLastModified = headers?['last-modified'];
            if (!_shouldDownload(cached.lastModified, serverLastModified)) {
              skippedCount++;
              onProgress?.call(i + 1, total, skippedCount);
              continue;
            }
          }
        }

        final response = await _fetchPageResponse(episode.url);
        final content = site.parseEpisode(response.body);
        final lastModified = response.headers['last-modified'];

        await saveEpisode(
          directory: dir,
          index: episode.index,
          title: episode.title,
          content: content,
          totalEpisodes: total,
        );
        if (episodeCacheRepository != null) {
          await episodeCacheRepository.upsert(EpisodeCache(
            url: urlStr,
            episodeIndex: episode.index,
            title: episode.title,
            lastModified: lastModified,
            downloadedAt: DateTime.now(),
          ));
        }
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

  void dispose() {
    _client.close();
  }
}
