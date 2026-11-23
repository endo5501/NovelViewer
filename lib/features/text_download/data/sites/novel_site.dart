import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/text_download/data/sites/aozora_site.dart';
import 'package:novel_viewer/features/text_download/data/sites/generic_web_site.dart';
import 'package:novel_viewer/features/text_download/data/sites/hameln_site.dart';
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
  final Uri? nextPageUrl;

  const NovelIndex({
    required this.title,
    required this.episodes,
    this.bodyContent,
    this.nextPageUrl,
  });
}

String extractParagraphText(dynamic element) {
  final blocks = element.querySelectorAll('p');
  if (blocks.isEmpty) return blockToText(element);
  return blocks.map(blockToText).join('\n');
}

abstract class NovelSite {
  String get siteType;
  bool canHandle(Uri url);
  String extractNovelId(Uri url);
  Uri normalizeUrl(Uri url) => url;
  Map<String, String> requestHeaders(Uri url) => const {};
  String decodeBody(http.Response response) => response.body;
  NovelIndex parseIndex(String html, Uri baseUrl);
  String parseEpisode(String html);
}

class NovelSiteRegistry {
  final List<NovelSite> _sites = [
    NarouSite(),
    KakuyomuSite(),
    AozoraSite(),
    HamelnSite(),
    // Fallback: must stay LAST so specialized adapters keep priority. Accepts
    // any http/https URL the others do not claim (F119 scheme check already
    // ran above), so no web URL is "unsupported" anymore — extraction failures
    // surface later as EmptyIndexException.
    GenericWebSite(),
  ];

  NovelSite? findSite(Uri url) {
    if (url.host.isEmpty) return null;
    // F119: only resolve a site for web URLs. Non-web schemes (javascript:,
    // file:, ftp:, ...) are rejected here once for all adapters. http is
    // accepted but every adapter's normalizeUrl upgrades it to https before the
    // actual fetch (so the request and the stored URL are always https), which
    // keeps backward-compatibility with previously-entered http links (e.g.
    // Aozora Bunko) without downgrading transport security.
    if (url.scheme != 'https' && url.scheme != 'http') return null;
    for (final site in _sites) {
      if (site.canHandle(url)) return site;
    }
    return null;
  }
}

/// The library folder a novel downloaded from [normalizedUrl] lives in:
/// `<siteType>_<novel id>`. The single rule for the download and for checking
/// a URL against a folder.
String novelFolderName(NovelSite site, Uri normalizedUrl) {
  return '${site.siteType}_${site.extractNovelId(normalizedUrl)}';
}

/// Whether downloading [url] would produce the novel in [folderName]: a site
/// other than generic web handles it and its folder name is [folderName].
/// A URL from a synced record is used as-is for the download, so one that
/// leads anywhere else is refused (remote-novel-download).
bool urlPointsToNovelFolder(
  String url,
  String folderName, {
  NovelSiteRegistry? registry,
}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final site = (registry ?? NovelSiteRegistry()).findSite(uri);
  if (site == null || site is GenericWebSite) return false;
  try {
    return novelFolderName(site, site.normalizeUrl(uri)) == folderName;
  } on ArgumentError {
    return false;
  }
}
