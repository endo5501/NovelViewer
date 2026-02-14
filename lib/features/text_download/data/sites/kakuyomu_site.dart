import 'package:html/parser.dart' as html_parser;
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

class KakuyomuSite implements NovelSite {
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

  static final _titleSelectors = [
    '#workTitle',
    'h1',
    '.work-title',
  ];

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

    String title = '';
    for (final selector in _titleSelectors) {
      final element = document.querySelector(selector);
      if (element != null && element.text.trim().isNotEmpty) {
        title = element.text.trim();
        break;
      }
    }

    final episodes = <Episode>[];
    final links = document.querySelectorAll('a[href*="/episodes/"]');
    for (final (i, link) in links.indexed) {
      final href = link.attributes['href'];
      if (href == null) continue;
      final resolvedUrl = baseUrl.resolve(href);
      episodes.add(Episode(
        index: i + 1,
        title: link.text.trim(),
        url: resolvedUrl,
      ));
    }

    return NovelIndex(title: title, episodes: episodes);
  }

  @override
  String parseEpisode(String html) {
    final document = html_parser.parse(html);

    for (final selector in _bodySelectors) {
      final element = document.querySelector(selector);
      if (element == null) continue;

      final blocks = element.querySelectorAll('p');
      if (blocks.isEmpty) return _blockToText(element);

      return blocks.map(_blockToText).join('\n');
    }

    return '';
  }

  static String _blockToText(dynamic element) {
    const textNodeType = 3;
    const elementNodeType = 1;

    final buffer = StringBuffer();
    for (final node in element.nodes) {
      if (node.nodeType == textNodeType) {
        buffer.write(node.text);
      } else if (node.nodeType == elementNodeType) {
        final tagName = node.localName?.toLowerCase() ?? '';
        if (tagName == 'br') {
          buffer.write('\n');
        } else if (tagName == 'ruby') {
          buffer.write(node.outerHtml);
        } else {
          buffer.write(_blockToText(node));
        }
      }
    }
    return buffer.toString().trim();
  }

  Uri normalizeUrl(Uri url) {
    final path = url.path;
    final match = RegExp(r'/works/(\d+)').firstMatch(path);
    if (match != null) {
      return Uri.parse('https://${url.host}/works/${match.group(1)}');
    }
    return url;
  }
}
