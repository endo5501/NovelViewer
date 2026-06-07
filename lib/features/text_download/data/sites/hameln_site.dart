import 'package:html/parser.dart' as html_parser;
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

/// Site adapter for ハーメルン (https://syosetu.org).
///
/// Hameln serves UTF-8 pages and does not gate R-18 works behind an
/// age-verification cookie for direct URL access, so [requestHeaders] and
/// [decodeBody] use the base-class defaults.
class HamelnSite extends NovelSite {
  static final _idPattern = RegExp(r'/novel/(\d+)');
  // Episode links are relative file references like `./4.html` (or `4.html`).
  // Anchoring the pattern excludes absolute cross-links to other novels
  // (e.g. `//syosetu.org/novel/999/1.html` in a related-works table).
  static final _episodeHrefPattern = RegExp(r'^(?:\./)?\d+\.html$');
  static const _allowedHosts = {'syosetu.org', 'www.syosetu.org'};

  @override
  String get siteType => 'hameln';

  // Require a boundary after the id so `/novel/123abc` is not mistaken for
  // novel 123 (which normalizeUrl would otherwise silently rewrite).
  static final _novelPathPattern = RegExp(r'^/novel/\d+(?:/|$)');
  // Hameln prepends a sequential display counter ("3　") to episode link text;
  // it is not part of the author's subtitle, so strip a single leading one.
  static final _displayCounterPattern = RegExp(r'^\d+　');

  @override
  bool canHandle(Uri url) {
    return _allowedHosts.contains(url.host) &&
        _novelPathPattern.hasMatch(url.path);
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
      // Pick the anchor that points to an episode file. Use the href (the
      // N.html file number) as the source of truth: the displayed episode
      // number can differ from the file number when episodes are deleted or
      // reordered, and a row may contain other anchors (e.g. an illustration
      // link) before the episode link.
      dynamic link;
      String? href;
      for (final anchor in row.querySelectorAll('a')) {
        final candidate = anchor.attributes['href'];
        if (candidate != null && _episodeHrefPattern.hasMatch(candidate)) {
          link = anchor;
          href = candidate;
          break;
        }
      }
      if (link == null || href == null) continue;

      episodes.add(Episode(
        index: episodes.length + 1,
        title: link.text.trim().replaceFirst(_displayCounterPattern, ''),
        url: baseUrl.resolve(href),
        updatedAt: _extractUpdateDate(row),
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
    // #honbun typically starts with a spacer paragraph (<p>　</p>); trim the
    // resulting leading/trailing blank lines while preserving internal ones.
    return extractParagraphText(honbun).trim();
  }

  /// Extracts the update date from a table-of-contents row. Prefers the
  /// `<nobr>` date cell; falls back to the last `<td>` only when there are at
  /// least two cells (so the title cell is never mistaken for the date).
  /// Returns null when no date cell is present.
  String? _extractUpdateDate(dynamic row) {
    final nobr = row.querySelector('nobr');
    String? text;
    if (nobr != null) {
      text = nobr.text.trim();
    } else {
      final cells = row.querySelectorAll('td');
      if (cells.length >= 2) {
        text = cells.last.text.trim();
      }
    }
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String _extractTitle(dynamic document) {
    // Serial index pages expose the title via schema.org markup.
    final nameEl = document.querySelector('span[itemprop="name"]');
    if (nameEl != null && nameEl.text.trim().isNotEmpty) {
      return nameEl.text.trim();
    }
    // Fallback (e.g. single-part works): derive from the <title> tag.
    // Format is "<work> - ハーメルン" or, for single-part works, the work
    // title is duplicated as "<work> - <work> - ハーメルン".
    final titleTag = document.querySelector('title')?.text.trim() ?? '';
    if (titleTag.isEmpty) return '';
    final stripped =
        titleTag.replaceFirst(RegExp(r'\s*-\s*ハーメルン\s*$'), '').trim();
    // Collapse an exact duplication ("X - X" -> "X") without truncating a
    // title that legitimately contains " - ".
    final parts = stripped.split(' - ');
    if (parts.length >= 2 && parts.length.isEven) {
      final half = parts.length ~/ 2;
      var duplicated = true;
      for (var i = 0; i < half; i++) {
        if (parts[i] != parts[half + i]) {
          duplicated = false;
          break;
        }
      }
      if (duplicated) {
        return parts.sublist(0, half).join(' - ').trim();
      }
    }
    return stripped;
  }
}
