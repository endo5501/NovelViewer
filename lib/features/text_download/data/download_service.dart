import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

typedef ProgressCallback = void Function(int current, int total);

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
  final Uri url;

  const DownloadResult({
    required this.siteType,
    required this.novelId,
    required this.title,
    required this.folderName,
    required this.episodeCount,
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

  Future<String> fetchPage(Uri url) async {
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

  Future<DownloadResult> downloadNovel({
    required NovelSite site,
    required Uri url,
    required String outputPath,
    ProgressCallback? onProgress,
  }) async {
    final folderName = buildFolderName(site, url);
    final novelId = site.extractNovelId(url);
    final indexHtml = await fetchPage(url);
    final novelIndex = site.parseIndex(indexHtml, url);

    final dir = await createNovelDirectory(outputPath, folderName);
    final total = novelIndex.episodes.length;
    var downloadedCount = 0;

    for (final (i, episode) in novelIndex.episodes.indexed) {
      try {
        if (i > 0) {
          await Future.delayed(requestDelay);
        }
        final episodeHtml = await fetchPage(episode.url);
        final content = site.parseEpisode(episodeHtml);

        await saveEpisode(
          directory: dir,
          index: episode.index,
          title: episode.title,
          content: content,
          totalEpisodes: total,
        );
        downloadedCount++;
      } catch (e) {
        // Skip failed episodes and continue
      }
      onProgress?.call(i + 1, total);
    }

    return DownloadResult(
      siteType: site.siteType,
      novelId: novelId,
      title: novelIndex.title,
      folderName: folderName,
      episodeCount: downloadedCount,
      url: url,
    );
  }

  void dispose() {
    _client.close();
  }
}
