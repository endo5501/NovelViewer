import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

class KakuyomuSite extends NovelSite {
  @override
  String get siteType => 'kakuyomu';

  @override
  String extractNovelId(Uri url) {
    final match = RegExp(r'/works/(\d+)').firstMatch(url.path);
    if (match == null) {
      throw ArgumentError('Cannot extract novel ID from URL: $url');
    }
    return match.group(1)!;
  }

  static final _bodySelectors = [
    '.widget-episodeBody__content',
    '.widget-episodeBody',
  ];

  @override
  bool canHandle(Uri url) {
    return url.host.contains('kakuyomu.jp');
  }

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    final document = html_parser.parse(html);
    final scriptElement =
        document.querySelector('script[id="__NEXT_DATA__"]');
    if (scriptElement == null) {
      throw ArgumentError(
          'Kakuyomu __NEXT_DATA__ script tag not found in index page');
    }

    final raw = scriptElement.text;
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw ArgumentError(
          'Failed to parse Kakuyomu __NEXT_DATA__ JSON: ${e.message}');
    }

    final apollo = _readPath(decoded, ['props', 'pageProps', '__APOLLO_STATE__']);
    if (apollo is! Map) {
      throw ArgumentError(
          'Kakuyomu __APOLLO_STATE__ not found in __NEXT_DATA__');
    }

    final workId = extractNovelId(baseUrl);
    final work = apollo['Work:$workId'];
    if (work is! Map) {
      throw ArgumentError(
          'Kakuyomu Work entity not found in Apollo state for id: $workId');
    }

    final title = (work['title'] as String?) ?? '';
    final tocList = (work['tableOfContentsV2'] as List?) ?? const [];

    final episodes = <Episode>[];
    var index = 1;
    for (final chapterRef in tocList) {
      final chapter = _resolveRef(apollo, chapterRef);
      if (chapter == null) continue;
      final episodeRefs = (chapter['episodeUnions'] as List?) ?? const [];
      for (final epRef in episodeRefs) {
        final ep = _resolveRef(apollo, epRef);
        if (ep == null) continue;
        final epId = ep['id'] as String?;
        if (epId == null) continue;
        final epTitle = (ep['title'] as String?) ?? '';
        final publishedAt = ep['publishedAt'] as String?;
        final url = Uri.parse(
            'https://${baseUrl.host}/works/$workId/episodes/$epId');
        episodes.add(Episode(
          index: index++,
          title: epTitle,
          url: url,
          updatedAt: publishedAt,
        ));
      }
    }

    return NovelIndex(title: title, episodes: episodes);
  }

  @override
  String parseEpisode(String html) {
    final document = html_parser.parse(html);

    for (final selector in _bodySelectors) {
      final element = document.querySelector(selector);
      if (element == null) continue;

      return extractParagraphText(element);
    }

    return '';
  }

  @override
  Uri normalizeUrl(Uri url) {
    final path = url.path;
    final match = RegExp(r'/works/(\d+)').firstMatch(path);
    if (match != null) {
      return Uri.parse('https://${url.host}/works/${match.group(1)}');
    }
    return url;
  }

  Object? _readPath(dynamic root, List<String> path) {
    dynamic current = root;
    for (final key in path) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current;
  }

  Map? _resolveRef(Map apollo, dynamic ref) {
    if (ref is! Map) return null;
    final key = ref['__ref'];
    if (key is! String) return null;
    final entity = apollo[key];
    return entity is Map ? entity : null;
  }
}
