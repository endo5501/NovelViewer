import 'package:html/parser.dart' as html_parser;
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

class NarouSite implements NovelSite {
  @override
  String get siteType => 'narou';

  @override
  String extractNovelId(Uri url) {
    final match = RegExp(r'/(n\w+)').firstMatch(url.path);
    if (match == null) {
      throw ArgumentError('Cannot extract novel ID from URL: $url');
    }
    return match.group(1)!;
  }

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

    // Try container-based parsing first (extracts both link and update date)
    final containers = document.querySelectorAll('.p-eplist__sublist');
    if (containers.isNotEmpty) {
      for (final (i, container) in containers.indexed) {
        final link = container.querySelector('.p-eplist__subtitle') ??
            container.querySelector('a');
        if (link == null) continue;
        final href = link.attributes['href'] ??
            link.querySelector('a')?.attributes['href'];
        if (href == null) continue;
        final resolvedUrl = baseUrl.resolve(href);
        final updatedAt = _extractUpdateDate(container);
        episodes.add(Episode(
          index: i + 1,
          title: link.text.trim(),
          url: resolvedUrl,
          updatedAt: updatedAt,
        ));
      }
    } else {
      // Fallback to link-only selectors (no update date available)
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
    }

    String? bodyContent;
    if (episodes.isEmpty) {
      final text = parseEpisode(html);
      if (text.isNotEmpty) {
        bodyContent = text;
      }
    }

    // Detect pagination: look for "次へ" link with ?p= parameter
    Uri? nextPageUrl;
    final nextLink = document.querySelectorAll('a[href*="?p="]').cast<dynamic>().firstWhere(
      (link) => link.text.trim() == '次へ',
      orElse: () => null,
    );
    if (nextLink != null) {
      nextPageUrl = baseUrl.resolve(nextLink.attributes['href']!);
    }

    return NovelIndex(
      title: title,
      episodes: episodes,
      bodyContent: bodyContent,
      nextPageUrl: nextPageUrl,
    );
  }

  @override
  String parseEpisode(String html) {
    final document = html_parser.parse(html);

    for (final selector in _bodySelectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isEmpty) continue;

      final texts = elements.expand((element) {
        final blocks = element.children.where((child) {
          final tag = child.localName?.toLowerCase();
          return tag == 'p' || tag == 'div';
        }).toList();
        return (blocks.isEmpty ? [element] : blocks).map(blockToText);
      });

      return texts.join('\n');
    }

    return '';
  }

  static final _datePattern = RegExp(r'(\d{4}/\d{2}/\d{2} \d{2}:\d{2})');

  static String? _extractUpdateDate(dynamic container) {
    final updateDiv = container.querySelector('.p-eplist__update');
    if (updateDiv == null) return null;

    // Check for revision date in <span title="YYYY/MM/DD HH:MM 改稿">
    final revisionSpan = updateDiv.querySelector('span[title]');
    if (revisionSpan != null) {
      final title = revisionSpan.attributes['title'] as String?;
      if (title != null) {
        final match = _datePattern.firstMatch(title);
        if (match != null) return match.group(1);
      }
    }

    // Fall back to publish date text
    final text = updateDiv.text.trim();
    final match = _datePattern.firstMatch(text);
    return match?.group(1);
  }

  @override
  Uri normalizeUrl(Uri url) {
    final path = url.path;
    final match = RegExp(r'/(n\w+)').firstMatch(path);
    if (match != null) {
      return Uri.parse('https://${url.host}/${match.group(1)}/');
    }
    return url;
  }
}
