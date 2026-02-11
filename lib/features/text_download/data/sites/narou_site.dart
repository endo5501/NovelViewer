import 'package:html/parser.dart' as html_parser;
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

class NarouSite implements NovelSite {
  static final _titleSelectors = [
    '.p-novel__title',
    '.novel_title',
    '#novel_title',
    'h1',
  ];

  static final _bodySelectors = [
    '.js-novel-text.p-novel__text',
    '#novel_honbun',
    '.novel_honbun',
    '.novel_view',
  ];

  static final _episodeLinkSelectors = [
    '.p-eplist__subtitle',
    '.novel_sublist2 a',
    '.novel_sublist a',
    '.index_box a',
    '.index_box2 a',
  ];

  @override
  bool canHandle(Uri url) {
    return url.host.contains('syosetu.com');
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
    for (final selector in _episodeLinkSelectors) {
      final links = document.querySelectorAll(selector);
      if (links.isNotEmpty) {
        for (final (i, link) in links.indexed) {
          final href = link.attributes['href'] ??
              link.querySelector('a')?.attributes['href'];
          if (href == null) continue;
          final resolvedUrl = baseUrl.resolve(href);
          episodes.add(Episode(
            index: i + 1,
            title: link.text.trim(),
            url: resolvedUrl,
          ));
        }
        break;
      }
    }

    return NovelIndex(title: title, episodes: episodes);
  }

  @override
  String parseEpisode(String html) {
    final document = html_parser.parse(html);

    for (final selector in _bodySelectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        final buffer = StringBuffer();
        for (final element in elements) {
          final blocks = element.querySelectorAll('p, div');
          if (blocks.isNotEmpty) {
            for (final block in blocks) {
              final text = _blockToText(block);
              if (text.isNotEmpty) {
                if (buffer.isNotEmpty) buffer.write('\n\n');
                buffer.write(text);
              }
            }
          } else {
            final text = _blockToText(element);
            if (text.isNotEmpty) {
              if (buffer.isNotEmpty) buffer.write('\n\n');
              buffer.write(text);
            }
          }
        }
        return buffer.toString();
      }
    }

    return '';
  }

  String _blockToText(dynamic element) {
    final buffer = StringBuffer();
    for (final node in element.nodes) {
      if (node.nodeType == 3) {
        // Text node
        buffer.write(node.text);
      } else if (node.nodeType == 1) {
        // Element node
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
    final match = RegExp(r'/(n\w+)').firstMatch(path);
    if (match != null) {
      return Uri.parse('https://${url.host}/${match.group(1)}/');
    }
    return url;
  }
}
