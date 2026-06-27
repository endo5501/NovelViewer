import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:euc/euc.dart';
import 'package:euc/jis.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

/// Fallback adapter for arbitrary static web pages that no dedicated site
/// adapter claims. Registered LAST in [NovelSiteRegistry] so the specialized
/// adapters keep priority; only http/https URLs that fall through reach here.
///
/// It extracts a single article body via a multi-stage heuristic
/// (noise removal -> semantic element -> known CMS containers -> text-density
/// fallback) and a title (og:title -> h1 -> title). The result feeds the same
/// short-story `bodyContent` path as Aozora, so all downstream features
/// (LLM analysis, TTS, search, viewer) work unchanged.
class GenericWebSite extends NovelSite {
  /// The `siteType` identifying a generic-web collection, shared by the adapter,
  /// the collection download provider, and the dialog's collection filter so the
  /// magic string lives in one place.
  static const String siteTypeId = 'web';

  /// Minimum extracted body length (characters). Shorter results are treated as
  /// extraction failures (JS-rendered page, typo URL, ...) and dropped so the
  /// existing [EmptyIndexException] guard fires.
  static const int minBodyLength = 200;

  /// Link-text penalty coefficient for the density fallback.
  static const double linkPenaltyK = 1.0;

  /// Tags removed before extraction (boilerplate: nav, ads, chrome, scripts).
  static const Set<String> _noiseTags = {
    'script',
    'style',
    'nav',
    'header',
    'footer',
    'aside',
    'form',
    'noscript',
  };

  /// Known CMS / blog body containers, tried in order after semantic elements.
  static const List<String> _cmsSelectors = [
    '.entry-content',
    '.post-content',
    '.article-body',
    '.article-content',
    '.post-body',
    '.entry-body',
    '.entry',
    '.post',
    '.note-common-styles__textnote-body',
    '#content',
  ];

  @override
  String get siteType => siteTypeId;

  @override
  bool canHandle(Uri url) => url.scheme == 'https' || url.scheme == 'http';

  /// No stable per-site id exists for arbitrary URLs. A short hash of the
  /// normalized URL satisfies the interface; the collection download flow does
  /// not rely on it (collections are identified by their folder name).
  @override
  String extractNovelId(Uri url) {
    final digest = sha256.convert(utf8.encode(normalizeUrl(url).toString()));
    return digest.toString().substring(0, 16);
  }

  /// Drop the fragment (which never identifies a distinct article) so the
  /// stored/fetched URL is stable. Unlike the specialized adapters, the scheme
  /// is PRESERVED: a generic page may be served over plain http only (common for
  /// older personal blogs), and forcing https would break the fetch.
  @override
  Uri normalizeUrl(Uri url) {
    return url.hasFragment ? url.removeFragment() : url;
  }

  /// Decodes the body using charset detection: Content-Type header ->
  /// `<meta charset>` / http-equiv -> UTF-8 fallback. Handles legacy Japanese
  /// blogs served as Shift_JIS / EUC-JP.
  @override
  String decodeBody(http.Response response) {
    final bytes = response.bodyBytes;
    final charset = _charsetFromContentType(response.headers['content-type']) ??
        _charsetFromMeta(bytes);
    return _decodeBytes(bytes, charset);
  }

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    final document = html_parser.parse(html);
    final title = _extractTitle(document);
    final body = _extractBody(document);
    final bodyContent = body.trim().length >= minBodyLength ? body : null;

    return NovelIndex(
      title: title,
      episodes: const [],
      bodyContent: bodyContent,
    );
  }

  @override
  String parseEpisode(String html) {
    final document = html_parser.parse(html);
    return _extractBody(document);
  }

  // --- title -------------------------------------------------------------

  String _extractTitle(Document document) {
    final ogTitle = document
        .querySelector('meta[property="og:title"]')
        ?.attributes['content']
        ?.trim();
    if (ogTitle != null && ogTitle.isNotEmpty) return ogTitle;

    final h1 = document.querySelector('h1')?.text.trim();
    if (h1 != null && h1.isNotEmpty) return h1;

    return document.querySelector('title')?.text.trim() ?? '';
  }

  // --- body extraction ---------------------------------------------------

  String _extractBody(Document document) {
    _removeNoise(document);
    final main = _selectMainElement(document);
    if (main == null) return '';
    return extractParagraphText(main);
  }

  void _removeNoise(Document document) {
    for (final tag in _noiseTags) {
      for (final element in document.querySelectorAll(tag)) {
        element.remove();
      }
    }
  }

  Element? _selectMainElement(Document document) {
    // 1. Semantic elements.
    for (final selector in const ['article', 'main', '[role="main"]']) {
      final element = document.querySelector(selector);
      if (element != null && element.text.trim().isNotEmpty) return element;
    }

    // 2. Known CMS / blog containers.
    for (final selector in _cmsSelectors) {
      final element = document.querySelector(selector);
      if (element != null && element.text.trim().isNotEmpty) return element;
    }

    // 3. Text-density fallback: prefer the element with the most direct
    // paragraph text, penalized by direct link text. Scoring direct <p>
    // children (not all descendants) avoids the root container always winning.
    final body = document.body;
    if (body == null) return null;

    Element? best;
    double bestScore = 0;
    for (final element in body.querySelectorAll('*')) {
      final score = _directParagraphTextLength(element) -
          linkPenaltyK * _directLinkTextLength(element);
      if (score > bestScore) {
        bestScore = score;
        best = element;
      }
    }
    return best ?? body;
  }

  double _directParagraphTextLength(Element element) {
    var total = 0;
    for (final child in element.children) {
      if (child.localName == 'p') {
        total += child.text.trim().length;
      }
    }
    return total.toDouble();
  }

  double _directLinkTextLength(Element element) {
    var total = 0;
    for (final anchor in element.querySelectorAll('a')) {
      total += anchor.text.trim().length;
    }
    return total.toDouble();
  }

  // --- charset detection -------------------------------------------------

  String? _charsetFromContentType(String? contentType) {
    if (contentType == null) return null;
    final match =
        RegExp(r'charset=([\w-]+)', caseSensitive: false).firstMatch(contentType);
    return match?.group(1);
  }

  String? _charsetFromMeta(List<int> bytes) {
    // Decode the head as latin1 (byte-preserving) to read the declared charset
    // without needing to know the encoding yet. Only the ASCII meta markup
    // matters here.
    final head = latin1.decode(
      bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes,
      allowInvalid: true,
    );
    final metaCharset =
        RegExp(r'<meta[^>]+charset=["\x27]?([\w-]+)', caseSensitive: false)
            .firstMatch(head);
    return metaCharset?.group(1);
  }

  String _decodeBytes(List<int> bytes, String? charset) {
    final normalized = charset?.toLowerCase().replaceAll('_', '-');
    switch (normalized) {
      case 'shift-jis':
      case 'shift_jis':
      case 'shiftjis':
      case 'sjis':
      case 'ms932':
      case 'windows-31j':
      case 'cp932':
        return ShiftJIS().decode(bytes);
      case 'euc-jp':
      case 'eucjp':
      case 'x-euc-jp':
        return EucJP().decode(bytes);
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }
}
