import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

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

typedef ProgressCallback = void Function(int current, int total);

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
    String novelTitle,
  ) async {
    final dirName = safeName(novelTitle);
    final dir = Directory('$parentPath/$dirName');
    await dir.create(recursive: true);
    return dir;
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

  Future<void> downloadNovel({
    required NovelSite site,
    required Uri url,
    required String outputPath,
    ProgressCallback? onProgress,
  }) async {
    final indexHtml = await fetchPage(url);
    final novelIndex = site.parseIndex(indexHtml, url);

    final dir = await createNovelDirectory(outputPath, novelIndex.title);
    final total = novelIndex.episodes.length;

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
      } catch (e) {
        // Skip failed episodes and continue
      }
      onProgress?.call(i + 1, total);
    }
  }

  void dispose() {
    _client.close();
  }
}
