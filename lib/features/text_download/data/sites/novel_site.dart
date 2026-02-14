import 'package:novel_viewer/features/text_download/data/sites/narou_site.dart';
import 'package:novel_viewer/features/text_download/data/sites/kakuyomu_site.dart';

/// Converts an HTML element to plain text, preserving `<br>` as newlines and `<ruby>` as HTML.
String blockToText(dynamic element) {
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
        buffer.write(blockToText(node));
      }
    }
  }
  return buffer.toString().trim();
}

class Episode {
  final int index;
  final String title;
  final Uri url;
  final String? updatedAt;

  const Episode({
    required this.index,
    required this.title,
    required this.url,
    this.updatedAt,
  });
}

class NovelIndex {
  final String title;
  final List<Episode> episodes;
  final String? bodyContent;

  const NovelIndex({
    required this.title,
    required this.episodes,
    this.bodyContent,
  });
}

abstract class NovelSite {
  String get siteType;
  bool canHandle(Uri url);
  String extractNovelId(Uri url);
  NovelIndex parseIndex(String html, Uri baseUrl);
  String parseEpisode(String html);
}

class NovelSiteRegistry {
  final List<NovelSite> _sites = [
    NarouSite(),
    KakuyomuSite(),
  ];

  NovelSite? findSite(Uri url) {
    if (url.host.isEmpty) return null;
    for (final site in _sites) {
      if (site.canHandle(url)) return site;
    }
    return null;
  }
}
