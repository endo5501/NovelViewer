import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/sites/hameln_site.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

// Fixtures below faithfully reproduce the real ハーメルン (syosetu.org) HTML
// structure observed during exploration:
// - Multi-part index: <span itemprop="name"> title, chapter heading rows
//   (<tr><td colspan=2><strong>), and episode rows (<tr class="bgcolor2/3">)
//   whose link href file number can differ from the displayed episode number.
// - Episode body: <div id="honbun"> with <p> paragraphs, plus sibling
//   <div id="maegaki"> / <div id="atogaki"> author notes.
// - Single-part (短編): <div id="honbun"> present, no episode rows.

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
<table>
<tr><td colspan=2><strong>第一章</strong></td></tr>
<tr bgcolor="#FFFFFF" class="bgcolor3"><td width=60%><span id="1">　</span> <a href=./1.html style="text-decoration:none;">1　始まり</a></td><td><NOBR>2026年02月21日(土) 16:20(改)</NOBR></td></tr>
<tr bgcolor="#F5F5F5" class="bgcolor2"><td width=60%><span id="2">　</span> <a href=./2.html style="text-decoration:none;">2　出会い</a></td><td><NOBR>2026年02月22日(日) 10:00</NOBR></td></tr>
<tr><td colspan=2><strong>第二章</strong></td></tr>
<tr bgcolor="#FFFFFF" class="bgcolor3"><td width=60%><span id="4">　</span> <a href=./4.html style="text-decoration:none;">3　再会</a></td><td><NOBR>2026年02月25日(水) 22:58</NOBR></td></tr>
</table>
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
      expect(index.episodes.length, 3);
    });

    test('assigns sequential 1-based index', () {
      expect(index.episodes.map((e) => e.index), [1, 2, 3]);
    });

    test('episode title strips Hameln\'s leading display counter', () {
      // Link text is "3　再会"; the leading "3　" is Hameln's display counter
      // (the file number is 4.html), so the stored title is just "再会".
      expect(index.episodes[2].title, '再会');
    });

    test('URL uses href file number, not displayed episode number', () {
      // Displayed as "3　再会" but the link href is ./4.html
      expect(index.episodes[2].url.toString(),
          'https://syosetu.org/novel/402955/4.html');
    });

    test('first episode URL resolves from href', () {
      expect(index.episodes[0].url.toString(),
          'https://syosetu.org/novel/402955/1.html');
    });

    test('stores updatedAt verbatim including revision marker', () {
      expect(index.episodes[0].updatedAt, '2026年02月21日(土) 16:20(改)');
    });

    test('stores updatedAt verbatim without revision marker', () {
      expect(index.episodes[1].updatedAt, '2026年02月22日(日) 10:00');
    });

    test('does not populate bodyContent for multi-part work', () {
      expect(index.bodyContent, isNull);
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
<div class="ss"><table width=100%>
<tr bgcolor="#FFFFFF" class="bgcolor3"><td width=60%><span id="1">　</span> <a href=./1.html>1　通常</a></td><td><NOBR>2026年03月01日(日) 12:00</NOBR></td></tr>
<tr bgcolor="#F5F5F5" class="bgcolor2"><td width=60%><a href="//syosetu.org/?mode=ss_view&uid=1">挿絵</a> <a href=./3.html>2　挿絵回</a></td><td><NOBR>2026年03月02日(月) 09:00</NOBR></td></tr>
</table></div>
</div></body></html>
''';
      final index = site.parseIndex(html, baseUrl);
      expect(index.episodes.length, 2);
      expect(index.episodes[1].title, '挿絵回');
      expect(index.episodes[1].url.toString(),
          'https://syosetu.org/novel/402955/3.html');
    });

    test('excludes phantom rows linking to other novels (absolute href)', () {
      const html = '''
<html><head><title>堅牢テスト - ハーメルン</title></head>
<body><div id="maind" itemscope itemtype="https://schema.org/CreativeWork">
<div class="ss"><span itemprop="name">堅牢テスト</span></div>
<div class="ss"><table width=100%>
<tr bgcolor="#FFFFFF" class="bgcolor3"><td width=60%><a href=./1.html>1　通常</a></td><td><NOBR>2026年03月01日(日) 12:00</NOBR></td></tr>
</table></div>
<div class="ss"><table width=100%>
<tr bgcolor="#FFFFFF" class="bgcolor3"><td><a href="//syosetu.org/novel/999999/1.html">関連作品</a></td><td>2020年01月01日</td></tr>
</table></div>
</div></body></html>
''';
      final index = site.parseIndex(html, baseUrl);
      expect(index.episodes.length, 1);
      expect(index.episodes[0].url.toString(),
          'https://syosetu.org/novel/402955/1.html');
    });

    test('handles episode row without a date cell without crashing', () {
      const html = '''
<html><head><title>堅牢テスト - ハーメルン</title></head>
<body><div id="maind" itemscope itemtype="https://schema.org/CreativeWork">
<div class="ss"><span itemprop="name">堅牢テスト</span></div>
<div class="ss"><table width=100%>
<tr bgcolor="#FFFFFF" class="bgcolor3"><td><a href=./4.html>4　日付なし</a></td></tr>
</table></div>
</div></body></html>
''';
      final index = site.parseIndex(html, baseUrl);
      expect(index.episodes.length, 1);
      expect(index.episodes[0].updatedAt, isNull);
    });
  });

  group('parseIndex - display counter stripping', () {
    test('strips the leading counter but keeps named/unnumbered episodes', () {
      const html = '''
<html><head><title>連番テスト - ハーメルン</title></head>
<body><div id="maind" itemscope itemtype="https://schema.org/CreativeWork">
<div class="ss"><span itemprop="name">連番テスト</span></div>
<div class="ss"><table width=100%>
<tr bgcolor="#FFFFFF" class="bgcolor3"><td><a href=./1.html>プロローグ</a></td><td><NOBR>2026年01月01日(木) 00:00</NOBR></td></tr>
<tr bgcolor="#F5F5F5" class="bgcolor2"><td><a href=./2.html>24　京都姉妹校交流会</a></td><td><NOBR>2026年01月02日(金) 00:00</NOBR></td></tr>
</table></div>
</div></body></html>
''';
      final index =
          site.parseIndex(html, Uri.parse('https://syosetu.org/novel/1/'));
      expect(index.episodes[0].title, 'プロローグ');
      expect(index.episodes[1].title, '京都姉妹校交流会');
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
