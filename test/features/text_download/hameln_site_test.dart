import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/sites/hameln_site.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

// Fixtures below faithfully reproduce the real ハーメルン (syosetu.org) HTML
// structure observed 2026-08-13:
// - Multi-part index: <span itemprop="name"> title and a
//   <section class="episode-list"> list whose entries are
//   <li class="episode-list__item"> holding an <a class="episode-list__link">.
//   Chapter headings are <li class="episode-list__chapter">. The link's href
//   file number can differ from any number the author wrote into the title.
//   Each entry carries a <time class="episode-list__date"> (the publication
//   timestamp) and a <span class="episode-list__revision"> whose title
//   attribute holds the revision timestamp when the episode was revised.
// - Episode body: <div id="honbun"> with <p> paragraphs, plus sibling
//   <div id="maegaki"> / <div id="atogaki"> author notes. Unchanged by the
//   2026 index redesign.
// - Single-part (短編): <div id="honbun"> present, no episode list at all.

const _multiPartIndexHtml = '''
<html>
<head><title>テスト小説 - ハーメルン</title></head>
<body>
<div id="maind" itemscope itemtype="https://schema.org/CreativeWork">
<div class="ss">
<span style="font-size:150%" itemprop="name">テスト小説</span>
<div align="right">作者：<span itemprop="author"><a href="//syosetu.org/user/482579/">テスト作者</a></span></div>
</div>
<div class="ss">
<section class="episode-list" aria-label="話一覧">
  <ul class="episode-list__items">
    <li class="episode-list__chapter">
      <div class="episode-list__chapter-title">第一章</div>
    </li>
	<li class="episode-list__item">
	<a href="./1.html" class="episode-list__link">
		<span class="episode-list__mark"></span>
		<span class="episode-list__title" >プロローグ</span>
		<time class="episode-list__date" itemprop="datePublished" datetime="2026-02-21T16:20Z">2026/02/21 16:20</time>
		<span class="episode-list__revision" title="2026/03/01 06:05改稿">(<u>改</u>)</span>
	</a>
	</li>
	<li class="episode-list__item">
	<a href="./2.html" class="episode-list__link">
		<span class="episode-list__mark"></span>
		<span class="episode-list__title" >1　調伏の儀式</span>
		<time class="episode-list__date">2026/02/22 04:13</time>
		<span class="episode-list__revision"> </span>
	</a>
	</li>
    <li class="episode-list__chapter">
      <div class="episode-list__chapter-title">第二章</div>
    </li>
	<li class="episode-list__item">
	<a href="./4.html" class="episode-list__link">
		<span class="episode-list__mark"></span>
		<span class="episode-list__title" >3　運ぶための力</span>
		<time class="episode-list__date">2026/02/25 22:58</time>
		<span class="episode-list__revision"> </span>
	</a>
	</li>
	<li class="episode-list__item">
	<a href="./11.html" class="episode-list__link">
		<span class="episode-list__mark"></span>
		<span class="episode-list__title" >10 　京都参戦</span>
		<time class="episode-list__date" itemprop="dateModified" datetime="2026-03-02T09:00Z">2026/03/02 09:00</time>
		<span class="episode-list__revision" title="2026/03/05 21:10改稿">(<u>改</u>)</span>
	</a>
	</li>
  </ul>
</section>
</div>
</div>
</body>
</html>
''';

const _episodeHtml = '''
<html>
<body>
<div id="maind">
<div class="ss">
<div id="maegaki_open">前書きを表示する</div>
<div id="maegaki">これは前書きのテキストです。</div>
<div id="honbun"><p id="0">　</p><p id="1">本文の一段落目です。</p><p id="2">本文の二段落目です。</p></div>
<div id="atogaki_open">後書きを表示する</div>
<div id="atogaki">これは後書きのテキストです。</div>
</div>
</div>
</body>
</html>
''';

const _shortStoryHtml = '''
<html>
<head><title>短編作品 - 短編作品 - ハーメルン</title></head>
<body>
<div id="maind">
<div class="ss">
<p><span style="font-size:120%"><a href=./>短編作品</a></span> 　 作：<a href="//syosetu.org/user/516462/">短編作者</a></p>
<div id="honbun"><p id="1">これは短編の本文です。</p></div>
</div>
</div>
</body>
</html>
''';

/// Builds a one-episode index page whose revision span carries [revisionTitle]
/// (omitted entirely when null), so tests can compare `updatedAt` across
/// successive revisions of the same episode.
String _indexWithRevision(String? revisionTitle) {
  final revision = revisionTitle == null
      ? '<span class="episode-list__revision"> </span>'
      : '<span class="episode-list__revision" title="$revisionTitle">(<u>改</u>)</span>';
  return '''
<html><head><title>改稿テスト - ハーメルン</title></head>
<body><div id="maind" itemscope itemtype="https://schema.org/CreativeWork">
<div class="ss"><span itemprop="name">改稿テスト</span></div>
<div class="ss"><section class="episode-list"><ul class="episode-list__items">
	<li class="episode-list__item">
	<a href="./1.html" class="episode-list__link">
		<span class="episode-list__title" >第一話</span>
		<time class="episode-list__date">2026/02/21 16:20</time>
		$revision
	</a>
	</li>
</ul></section></div>
</div></body></html>
''';
}

void main() {
  late HamelnSite site;

  setUp(() {
    site = HamelnSite();
  });

  group('siteType', () {
    test('returns hameln', () {
      expect(site.siteType, 'hameln');
    });
  });

  group('canHandle', () {
    test('accepts novel index URL', () {
      expect(
        site.canHandle(Uri.parse('https://syosetu.org/novel/402955/')),
        isTrue,
      );
    });

    test('accepts episode URL', () {
      expect(
        site.canHandle(Uri.parse('https://syosetu.org/novel/402955/1.html')),
        isTrue,
      );
    });

    test('rejects top page URL', () {
      expect(
        site.canHandle(Uri.parse('https://syosetu.org/')),
        isFalse,
      );
    });

    test('rejects non-novel path', () {
      expect(
        site.canHandle(Uri.parse('https://syosetu.org/?mode=rank')),
        isFalse,
      );
    });

    test('rejects path with trailing non-digit after the id', () {
      expect(
        site.canHandle(Uri.parse('https://syosetu.org/novel/402955abc')),
        isFalse,
      );
    });

    test('accepts id without a trailing slash', () {
      expect(
        site.canHandle(Uri.parse('https://syosetu.org/novel/402955')),
        isTrue,
      );
    });

    test('rejects Narou (syosetu.com) URL', () {
      expect(
        site.canHandle(Uri.parse('https://ncode.syosetu.com/n9669bk/')),
        isFalse,
      );
    });
  });

  group('extractNovelId', () {
    test('extracts id from index URL', () {
      expect(
        site.extractNovelId(Uri.parse('https://syosetu.org/novel/402955/')),
        '402955',
      );
    });

    test('extracts id from episode URL', () {
      expect(
        site.extractNovelId(
            Uri.parse('https://syosetu.org/novel/402955/12.html')),
        '402955',
      );
    });

    test('throws ArgumentError when no id in path', () {
      expect(
        () => site.extractNovelId(Uri.parse('https://syosetu.org/')),
        throwsArgumentError,
      );
    });
  });

  group('normalizeUrl', () {
    test('normalizes episode URL to index URL', () {
      final normalized =
          site.normalizeUrl(Uri.parse('https://syosetu.org/novel/402955/3.html'));
      expect(normalized.toString(), 'https://syosetu.org/novel/402955/');
    });

    test('preserves index URL', () {
      final normalized =
          site.normalizeUrl(Uri.parse('https://syosetu.org/novel/402955/'));
      expect(normalized.toString(), 'https://syosetu.org/novel/402955/');
    });
  });

  group('requestHeaders', () {
    test('overrides UA with an honest, non-browser-impersonating User-Agent',
        () {
      // syosetu.org is behind Cloudflare, which 403s a spoofed Chrome UA that
      // lacks real-browser traits (e.g. brotli). An honest app UA is allowed.
      final headers =
          site.requestHeaders(Uri.parse('https://syosetu.org/novel/402955/'));
      expect(headers['User-Agent'], isNotNull);
      expect(headers['User-Agent'], isNot(contains('Chrome')));
      expect(headers['User-Agent'], isNot(contains('Mozilla')));
      expect(headers['User-Agent'], contains('NovelViewer'));
    });

    test('sends the R-18 age-confirmation cookie so gated works are reachable',
        () {
      // Some R-18 works (e.g. single-part stories) serve an age-confirmation
      // interstitial instead of the body unless the over18 cookie is present.
      final headers =
          site.requestHeaders(Uri.parse('https://syosetu.org/novel/415332/'));
      expect(headers['Cookie'], contains('over18'));
    });
  });

  group('parseIndex - multi-part', () {
    late NovelIndex index;
    final baseUrl = Uri.parse('https://syosetu.org/novel/402955/');

    setUp(() {
      index = site.parseIndex(_multiPartIndexHtml, baseUrl);
    });

    test('extracts title', () {
      expect(index.title, 'テスト小説');
    });

    test('flattens episodes across chapters', () {
      expect(index.episodes.length, 4);
    });

    test('assigns sequential 1-based index', () {
      expect(index.episodes.map((e) => e.index), [1, 2, 3, 4]);
    });

    test('URL uses href file number, not the number written in the title', () {
      // Title reads "3　運ぶための力" but the link href is ./4.html
      expect(index.episodes[2].url.toString(),
          'https://syosetu.org/novel/402955/4.html');
    });

    test('first episode URL resolves from href', () {
      expect(index.episodes[0].url.toString(),
          'https://syosetu.org/novel/402955/1.html');
    });

    test('does not populate bodyContent for multi-part work', () {
      expect(index.bodyContent, isNull);
    });
  });

  group('parseIndex - episode titles are stored verbatim', () {
    late NovelIndex index;

    setUp(() {
      index = site.parseIndex(
          _multiPartIndexHtml, Uri.parse('https://syosetu.org/novel/402955/'));
    });

    test('keeps a leading number written by the author', () {
      // Hameln does not prepend a display counter: the leading "3　" is part
      // of the author's own title and must survive.
      expect(index.episodes[2].title, '3　運ぶための力');
    });

    test('keeps a title that has no leading number', () {
      expect(index.episodes[0].title, 'プロローグ');
    });

    test('keeps a leading number followed by a half-width space', () {
      expect(index.episodes[3].title, '10 　京都参戦');
    });

    test('keeps a leading number directly followed by an ideographic space',
        () {
      expect(index.episodes[1].title, '1　調伏の儀式');
    });
  });

  group('parseIndex - updatedAt', () {
    late NovelIndex index;

    setUp(() {
      index = site.parseIndex(
          _multiPartIndexHtml, Uri.parse('https://syosetu.org/novel/402955/'));
    });

    test('stores the time text alone when the episode was never revised', () {
      expect(index.episodes[1].updatedAt, '2026/02/22 04:13');
    });

    test('appends the revision timestamp when the episode was revised', () {
      // <time> holds the publication timestamp and never changes on revision,
      // so the revision span's title attribute has to be part of the value.
      expect(index.episodes[0].updatedAt,
          '2026/02/21 16:20 (2026/03/01 06:05改稿)');
    });

    test('a second revision produces a different value', () {
      final first = site.parseIndex(_indexWithRevision('2026/02/27 23:54改稿'),
          Uri.parse('https://syosetu.org/novel/1/'));
      final second = site.parseIndex(_indexWithRevision('2026/03/01 06:05改稿'),
          Uri.parse('https://syosetu.org/novel/1/'));
      expect(first.episodes.single.updatedAt,
          isNot(second.episodes.single.updatedAt));
    });

    test('an unrevised episode differs from its later revised value', () {
      final unrevised = site.parseIndex(
          _indexWithRevision(null), Uri.parse('https://syosetu.org/novel/1/'));
      final revised = site.parseIndex(_indexWithRevision('2026/03/01 06:05改稿'),
          Uri.parse('https://syosetu.org/novel/1/'));
      expect(unrevised.episodes.single.updatedAt, '2026/02/21 16:20');
      expect(revised.episodes.single.updatedAt,
          isNot(unrevised.episodes.single.updatedAt));
    });
  });

  group('parseIndex - short story', () {
    late NovelIndex index;
    final baseUrl = Uri.parse('https://syosetu.org/novel/415221/');

    setUp(() {
      index = site.parseIndex(_shortStoryHtml, baseUrl);
    });

    test('extracts title', () {
      expect(index.title, '短編作品');
    });

    test('returns empty episodes list', () {
      expect(index.episodes, isEmpty);
    });

    test('populates bodyContent from honbun', () {
      expect(index.bodyContent, isNotNull);
      expect(index.bodyContent, contains('これは短編の本文です。'));
    });
  });

  group('parseEpisode', () {
    test('extracts honbun body with line breaks preserved', () {
      final text = site.parseEpisode(_episodeHtml);
      expect(text, contains('本文の一段落目です。'));
      expect(text, contains('本文の二段落目です。'));
    });

    test('excludes maegaki and atogaki', () {
      final text = site.parseEpisode(_episodeHtml);
      expect(text, isNot(contains('前書きのテキスト')));
      expect(text, isNot(contains('後書きのテキスト')));
    });

    test('returns empty string when no honbun', () {
      const html = '<html><body><div class="other">なし</div></body></html>';
      expect(site.parseEpisode(html), '');
    });
  });

  group('canHandle - www host', () {
    test('accepts www.syosetu.org', () {
      expect(
        site.canHandle(Uri.parse('https://www.syosetu.org/novel/402955/')),
        isTrue,
      );
    });
  });

  group('parseIndex - robustness', () {
    final baseUrl = Uri.parse('https://syosetu.org/novel/402955/');

    test('picks the episode anchor even when a non-episode anchor precedes it',
        () {
      const html = '''
<html><head><title>堅牢テスト - ハーメルン</title></head>
<body><div id="maind" itemscope itemtype="https://schema.org/CreativeWork">
<div class="ss"><span itemprop="name">堅牢テスト</span></div>
<div class="ss"><section class="episode-list"><ul class="episode-list__items">
	<li class="episode-list__item">
	<a href="./1.html" class="episode-list__link">
		<span class="episode-list__title" >通常</span>
		<time class="episode-list__date">2026/03/01 12:00</time>
	</a>
	</li>
	<li class="episode-list__item">
	<a href="//syosetu.org/?mode=ss_view&uid=1">挿絵</a>
	<a href="./3.html" class="episode-list__link">
		<span class="episode-list__title" >挿絵回</span>
		<time class="episode-list__date">2026/03/02 09:00</time>
	</a>
	</li>
</ul></section></div>
</div></body></html>
''';
      final index = site.parseIndex(html, baseUrl);
      expect(index.episodes.length, 2);
      expect(index.episodes[1].title, '挿絵回');
      expect(index.episodes[1].url.toString(),
          'https://syosetu.org/novel/402955/3.html');
    });

    test('excludes phantom entries linking to other novels (absolute href)',
        () {
      const html = '''
<html><head><title>堅牢テスト - ハーメルン</title></head>
<body><div id="maind" itemscope itemtype="https://schema.org/CreativeWork">
<div class="ss"><span itemprop="name">堅牢テスト</span></div>
<div class="ss"><section class="episode-list"><ul class="episode-list__items">
	<li class="episode-list__item">
	<a href="./1.html" class="episode-list__link">
		<span class="episode-list__title" >通常</span>
		<time class="episode-list__date">2026/03/01 12:00</time>
	</a>
	</li>
	<li class="episode-list__item">
	<a href="//syosetu.org/novel/999999/1.html" class="episode-list__link">
		<span class="episode-list__title" >関連作品</span>
		<time class="episode-list__date">2020/01/01 00:00</time>
	</a>
	</li>
</ul></section></div>
</div></body></html>
''';
      final index = site.parseIndex(html, baseUrl);
      expect(index.episodes.length, 1);
      expect(index.episodes[0].url.toString(),
          'https://syosetu.org/novel/402955/1.html');
    });

    test('handles an episode entry without a date cell without crashing', () {
      const html = '''
<html><head><title>堅牢テスト - ハーメルン</title></head>
<body><div id="maind" itemscope itemtype="https://schema.org/CreativeWork">
<div class="ss"><span itemprop="name">堅牢テスト</span></div>
<div class="ss"><section class="episode-list"><ul class="episode-list__items">
	<li class="episode-list__item">
	<a href="./4.html" class="episode-list__link">
		<span class="episode-list__title" >日付なし</span>
	</a>
	</li>
</ul></section></div>
</div></body></html>
''';
      final index = site.parseIndex(html, baseUrl);
      expect(index.episodes.length, 1);
      expect(index.episodes[0].updatedAt, isNull);
    });

    test('the retired bgcolor table markup yields no episodes and no body', () {
      // Regression guard: the adapter must not silently fall back to the
      // markup syosetu.org retired in 2026 — a page in that shape has to reach
      // the empty-index guard so the drift is reported.
      const html = '''
<html><head><title>旧マークアップ - ハーメルン</title></head>
<body><div id="maind" itemscope itemtype="https://schema.org/CreativeWork">
<div class="ss"><span itemprop="name">旧マークアップ</span></div>
<div class="ss"><table width=100%>
<tr><td colspan=2><strong>第一章</strong></td></tr>
<tr bgcolor="#FFFFFF" class="bgcolor3"><td width=60%><a href=./1.html>1　はじまり</a></td><td><NOBR>2026年02月21日(土) 16:20(改)</NOBR></td></tr>
<tr bgcolor="#F5F5F5" class="bgcolor2"><td width=60%><a href=./2.html>2　つづき</a></td><td><NOBR>2026年02月22日(日) 10:00</NOBR></td></tr>
</table></div>
</div></body></html>
''';
      final index = site.parseIndex(html, baseUrl);
      expect(index.episodes, isEmpty);
      expect(index.bodyContent, isNull);
    });
  });

  group('parseIndex - single-part title from heading', () {
    test('uses the self-link heading when work title != episode label', () {
      // The <title> tag is "<work> - <episode> - ハーメルン" with distinct
      // work/episode, so de-duplication cannot recover the work title; the
      // body heading <a href="./"> carries the clean work title. Note the
      // site writes the attribute unquoted (href=./), which the HTML parser
      // still resolves to "./".
      const html = '''
<html><head><title>ある日の日常 - 第1話 - ハーメルン</title></head>
<body><div id="maind">
<div class="ss"><p><span style="font-size:120%"><a href=./>ある日の日常</a></span> 　 作：<a href="//syosetu.org/user/1/">著者</a></p>
<div id="honbun"><p id="1">本文。</p></div>
</div></div></body></html>
''';
      final index =
          site.parseIndex(html, Uri.parse('https://syosetu.org/novel/415332/'));
      expect(index.title, 'ある日の日常');
    });
  });

  group('parseIndex - title with hyphen', () {
    test('preserves a short-story title containing " - "', () {
      const html = '''
<html><head><title>剣 - 盾 - 剣 - 盾 - ハーメルン</title></head>
<body><div id="maind">
<div class="ss"><p><span style="font-size:120%"><a href=./>剣 - 盾</a></span></p>
<div id="honbun"><p id="1">本文。</p></div>
</div></div></body></html>
''';
      final index =
          site.parseIndex(html, Uri.parse('https://syosetu.org/novel/100/'));
      expect(index.title, '剣 - 盾');
    });
  });

  group('parseEpisode - no leading blank line', () {
    test('trims the leading spacer paragraph', () {
      const html = '''
<html><body><div id="honbun"><p id="0">　</p><p id="1">本文の始まり。</p></div></body></html>
''';
      final text = site.parseEpisode(html);
      expect(text.startsWith('\n'), isFalse);
      expect(text, startsWith('本文の始まり。'));
    });
  });

  group('NovelSiteRegistry integration', () {
    test('findSite returns HamelnSite for Hameln URL', () {
      final registry = NovelSiteRegistry();
      final found =
          registry.findSite(Uri.parse('https://syosetu.org/novel/402955/'));
      expect(found, isA<HamelnSite>());
    });
  });
}
