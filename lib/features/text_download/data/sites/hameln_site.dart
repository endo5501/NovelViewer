import 'package:html/parser.dart' as html_parser;
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

/// Site adapter for ハーメルン (https://syosetu.org).
///
/// Hameln serves UTF-8 pages and does not gate R-18 works behind an
/// age-verification cookie for direct URL access, so [requestHeaders] and
/// [decodeBody] use the base-class defaults.
class HamelnSite extends NovelSite {
  static final _idPattern = RegExp(r'/novel/(\d+)');
  static final _episodeHrefPattern = RegExp(r'\d+\.html');

  @override
  String get siteType => 'hameln';

  @override
  bool canHandle(Uri url) {
    return url.host == 'syosetu.org' &&
        RegExp(r'^/novel/\d+').hasMatch(url.path);
  }

  @override
  String extractNovelId(Uri url) {
    final match = _idPattern.firstMatch(url.path);
    if (match == null) {
      throw ArgumentError('Cannot extract novel ID from URL: $url');
    }
    return match.group(1)!;
  }

  @override
  Uri normalizeUrl(Uri url) {
    final match = _idPattern.firstMatch(url.path);
    if (match != null) {
      return Uri.parse('https://syosetu.org/novel/${match.group(1)}/');
    }
    return url;
  }

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    final document = html_parser.parse(html);
    final title = _extractTitle(document);

    final episodes = <Episode>[];
    // Table-of-contents rows are styled with the bgcolor2/bgcolor3 classes.
    // Chapter heading rows (<tr><td colspan=2><strong>...) lack these classes
    // and are therefore naturally skipped (chapters are flattened away).
    final rows = document.querySelectorAll('tr').where((tr) {
      final classes = tr.classes;
      return classes.contains('bgcolor2') || classes.contains('bgcolor3');
    });

    for (final row in rows) {
      final link = row.querySelector('a');
      if (link == null) continue;
      final href = link.attributes['href'];
      // Use the link's href (the N.html file number) as the source of truth.
      // The displayed episode number can differ from the file number when
      // episodes are deleted or reordered.
      if (href == null || !_episodeHrefPattern.hasMatch(href)) continue;

      final updatedAt =
          (row.querySelector('nobr') ?? row.querySelectorAll('td').last)
              .text
              .trim();

      episodes.add(Episode(
        index: episodes.length + 1,
        title: link.text.trim(),
        url: baseUrl.resolve(href),
        updatedAt: updatedAt.isEmpty ? null : updatedAt,
      ));
    }

    String? bodyContent;
    if (episodes.isEmpty) {
      // Single-part (短編) work: no table-of-contents rows, body is on the
      // index page itself.
      final text = parseEpisode(html);
      if (text.isNotEmpty) {
        bodyContent = text;
      }
    }

    return NovelIndex(
      title: title,
      episodes: episodes,
      bodyContent: bodyContent,
    );
  }

  @override
  String parseEpisode(String html) {
    final document = html_parser.parse(html);
    // Only the #honbun element holds the story body. The author's preface
    // (#maegaki) and afterword (#atogaki) are intentionally excluded.
    final honbun = document.querySelector('#honbun');
    if (honbun == null) return '';
    return extractParagraphText(honbun);
  }

  String _extractTitle(dynamic document) {
    // Serial index pages expose the title via schema.org markup.
    final nameEl = document.querySelector('span[itemprop="name"]');
    if (nameEl != null && nameEl.text.trim().isNotEmpty) {
      return nameEl.text.trim();
    }
    // Fallback (e.g. single-part works): derive from the <title> tag.
    // Format is "<work> - ハーメルン" or "<work> - <episode> - ハーメルン".
    final titleTag = document.querySelector('title')?.text.trim() ?? '';
    if (titleTag.isEmpty) return '';
    var stripped =
        titleTag.replaceFirst(RegExp(r'\s*-\s*ハーメルン\s*$'), '').trim();
    final dashIndex = stripped.indexOf(' - ');
    if (dashIndex >= 0) {
      stripped = stripped.substring(0, dashIndex).trim();
    }
    return stripped;
  }
}
