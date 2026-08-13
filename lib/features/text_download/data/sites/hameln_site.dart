import 'package:html/parser.dart' as html_parser;
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

/// Site adapter for ハーメルン (https://syosetu.org).
///
/// Hameln serves UTF-8 pages, so [decodeBody] uses the base-class default.
/// [requestHeaders] overrides two things:
///  - User-Agent: syosetu.org sits behind Cloudflare, whose bot protection
///    403s the app's default spoofed Chrome User-Agent (a request that claims
///    to be Chrome but lacks real-browser traits such as brotli support). An
///    honest, non-browser identifier is allowed through and returns
///    gzip-encoded content that dart:io decodes automatically.
///  - Cookie: some R-18 works serve an age-confirmation interstitial instead
///    of the body unless the site's `over18` cookie is present.
class HamelnSite extends NovelSite {
  /// Honest, non-browser-impersonating User-Agent. Must NOT claim to be a
  /// mainstream browser, or Cloudflare's bot check rejects it with 403.
  static const _userAgent = 'NovelViewer (Flutter desktop app)';

  static final _idPattern = RegExp(r'/novel/(\d+)');
  // Episode links are relative file references like `./4.html` (or `4.html`).
  // Anchoring the pattern excludes absolute cross-links to other novels
  // (e.g. `//syosetu.org/novel/999/1.html` in a related-works list).
  static final _episodeHrefPattern = RegExp(r'^(?:\./)?\d+\.html$');
  static const _allowedHosts = {'syosetu.org', 'www.syosetu.org'};

  @override
  String get siteType => 'hameln';

  // Require a boundary after the id so `/novel/123abc` is not mistaken for
  // novel 123 (which normalizeUrl would otherwise silently rewrite).
  static final _novelPathPattern = RegExp(r'^/novel/\d+(?:/|$)');

  @override
  bool canHandle(Uri url) {
    return _allowedHosts.contains(url.host) &&
        _novelPathPattern.hasMatch(url.path);
  }

  @override
  Map<String, String> requestHeaders(Uri url) => const {
        'User-Agent': _userAgent,
        // Some R-18 works serve an age-confirmation interstitial instead of
        // the body unless this cookie is present. The site's own "はい" flow
        // (?mode=r18_cs_end) sets `over18=off`; sending it up front is
        // harmless for non-R-18 works and unlocks gated ones site-wide.
        'Cookie': 'over18=off',
      };

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
    // The table of contents is a <section class="episode-list"> whose entries
    // are <li class="episode-list__item">. Chapter headings are
    // <li class="episode-list__chapter"> and carry no episode link, so they
    // drop out on their own (chapters are flattened away).
    final entries = document.querySelectorAll('li.episode-list__item');

    for (final entry in entries) {
      // Pick the anchor that points to an episode file. Use the href (the
      // N.html file number) as the source of truth: any number the author
      // wrote into the title can differ from the file number when episodes are
      // deleted or reordered, and an entry may contain other anchors (e.g. an
      // illustration link) before the episode link.
      dynamic link;
      String? href;
      for (final anchor in entry.querySelectorAll('a')) {
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
        title: _extractEpisodeTitle(link),
        url: baseUrl.resolve(href),
        updatedAt: _extractUpdateDate(entry),
      ));
    }

    String? bodyContent;
    if (episodes.isEmpty) {
      // Single-part (短編) work: no episode list at all, body is on the
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

  /// Extracts the episode title from the episode link. The title lives in a
  /// dedicated `<span class="episode-list__title">`.
  ///
  /// The text is stored verbatim: Hameln does NOT prepend a display counter, so
  /// a leading number (`3　運ぶための力`) is part of the author's own title.
  ///
  /// If that span is ever dropped, falling back to the whole link text would
  /// swallow the date and revision marker, which are siblings inside the *same*
  /// anchor, and carry them into the episode file name and the episode cache.
  /// So the fallback subtracts them first.
  String _extractEpisodeTitle(dynamic link) {
    final titleEl = link.querySelector('span.episode-list__title');
    if (titleEl != null) return titleEl.text.trim();

    var text = link.text as String;
    final noise = [
      ...link.querySelectorAll('time.episode-list__date'),
      ...link.querySelectorAll('span.episode-list__revision'),
    ];
    for (final element in noise) {
      final fragment = element.text as String;
      if (fragment.isEmpty) continue;
      text = text.replaceFirst(fragment, '');
    }
    return text.trim();
  }

  /// Builds the `updatedAt` value of a table-of-contents entry so that every
  /// revision changes it.
  ///
  /// `<time class="episode-list__date">` holds the *publication* timestamp and
  /// does not change when an episode is revised; the visible revision marker is
  /// the constant text `(改)`. Only the revision span's `title` attribute
  /// (`2026/03/01 06:05改稿`) moves with each revision, so it is appended to the
  /// time text. Returns null when the entry has no `<time>` element (the
  /// download service then re-downloads, which is the safe fallback).
  ///
  /// The `<time>` element's `datetime` attribute is deliberately ignored: the
  /// site only emits it on the entries marked `itemprop="datePublished"` /
  /// `"dateModified"`, so most entries do not carry it.
  String? _extractUpdateDate(dynamic entry) {
    final time = entry.querySelector('time.episode-list__date');
    if (time == null) return null;
    final text = time.text.trim();
    if (text.isEmpty) return null;

    final revision = entry.querySelector('span.episode-list__revision');
    final revisedAt = revision?.attributes['title']?.trim();
    if (revisedAt == null || revisedAt.isEmpty) return text;
    return '$text ($revisedAt)';
  }

  String _extractTitle(dynamic document) {
    // Serial index pages expose the title via schema.org markup.
    final nameEl = document.querySelector('span[itemprop="name"]');
    if (nameEl != null && nameEl.text.trim().isNotEmpty) {
      return nameEl.text.trim();
    }
    // Single-part works lack the itemprop markup; their heading is a self-link
    // to the work root (<a href="./">work title</a>), which is the cleanest
    // source for the work title.
    final main = document.querySelector('#maind') ?? document;
    final selfLink = main.querySelector('a[href="./"]') ??
        main.querySelector('a[href="."]');
    if (selfLink != null && selfLink.text.trim().isNotEmpty) {
      return selfLink.text.trim();
    }

    // Last resort: derive from the <title> tag. Format is "<work> - ハーメルン"
    // or, for single-part works, the work title may be duplicated as
    // "<work> - <work> - ハーメルン".
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
