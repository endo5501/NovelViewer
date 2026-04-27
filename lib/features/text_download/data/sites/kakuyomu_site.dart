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
          'Kakuyomu __NEXT_DATA__ script tag not found in $baseUrl');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(scriptElement.text);
    } on FormatException catch (e) {
      throw ArgumentError(
          'Failed to parse Kakuyomu __NEXT_DATA__ JSON for $baseUrl: ${e.message}');
    }

    final props = decoded is Map ? decoded['props'] : null;
    final pageProps = props is Map ? props['pageProps'] : null;
    final apollo = pageProps is Map ? pageProps['__APOLLO_STATE__'] : null;
    if (apollo is! Map) {
      throw ArgumentError(
          'Kakuyomu __APOLLO_STATE__ not found in __NEXT_DATA__ for $baseUrl');
    }

    final workId = extractNovelId(baseUrl);
    final root = apollo['ROOT_QUERY'];
    if (root is! Map) {
      throw ArgumentError(
          'Kakuyomu ROOT_QUERY not found in Apollo state for $baseUrl');
    }
    final workRefField = 'work({"id":"$workId"})';
    final work = _resolveRef(apollo, root[workRefField]);
    if (work == null) {
      throw ArgumentError(
          'Kakuyomu Work entity unresolved via $workRefField for $baseUrl');
    }

    final title = (work['title'] as String?) ?? '';
    final tocRaw = work['tableOfContentsV2'];
    if (tocRaw is! List) {
      throw ArgumentError(
          'Kakuyomu Work.tableOfContentsV2 is not a List for $baseUrl');
    }

    final episodes = <Episode>[];
    var index = 1;
    for (final chapterRef in tocRaw) {
      final chapter = _resolveRef(apollo, chapterRef);
      if (chapter == null) {
        throw ArgumentError(
            'Kakuyomu TableOfContentsChapter unresolved for $baseUrl');
      }
      final episodeRefs = chapter['episodeUnions'];
      if (episodeRefs is! List) {
        throw ArgumentError(
            'Kakuyomu episodeUnions is not a List for $baseUrl');
      }
      for (final epRef in episodeRefs) {
        final ep = _resolveRef(apollo, epRef);
        if (ep == null) {
          throw ArgumentError(
              'Kakuyomu Episode unresolved for $baseUrl');
        }
        final epId = ep['id'] as String?;
        if (epId == null) {
          throw ArgumentError(
              'Kakuyomu Episode missing id for $baseUrl');
        }
        final epTitle = (ep['title'] as String?) ?? '';
        final publishedAt = ep['publishedAt'] as String?;
        final url = baseUrl.replace(
          path: '/works/$workId/episodes/$epId',
          query: null,
          fragment: null,
        );
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

  Map? _resolveRef(Map apollo, dynamic ref) {
    if (ref is! Map) return null;
    final key = ref['__ref'];
    if (key is! String) return null;
    final entity = apollo[key];
    return entity is Map ? entity : null;
  }
}
