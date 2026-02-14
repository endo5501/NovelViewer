import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/sites/narou_site.dart';

void main() {
  late NarouSite site;

  setUp(() {
    site = NarouSite();
  });

  group('canHandle', () {
    test('returns true for ncode.syosetu.com', () {
      expect(
        site.canHandle(Uri.parse('https://ncode.syosetu.com/n9669bk/')),
        isTrue,
      );
    });

    test('returns true for novel18.syosetu.com', () {
      expect(
        site.canHandle(Uri.parse('https://novel18.syosetu.com/n1234ab/')),
        isTrue,
      );
    });

    test('returns false for kakuyomu.jp', () {
      expect(
        site.canHandle(Uri.parse('https://kakuyomu.jp/works/123')),
        isFalse,
      );
    });
  });

  group('normalizeUrl', () {
    test('normalizes URL with trailing path', () {
      final url = Uri.parse('https://ncode.syosetu.com/n9669bk/1/');
      final normalized = site.normalizeUrl(url);
      expect(normalized.toString(), 'https://ncode.syosetu.com/n9669bk/');
    });

    test('keeps already normalized URL', () {
      final url = Uri.parse('https://ncode.syosetu.com/n9669bk/');
      final normalized = site.normalizeUrl(url);
      expect(normalized.toString(), 'https://ncode.syosetu.com/n9669bk/');
    });
  });

  group('parseIndex', () {
    test('extracts title and episodes from index page', () {
      const html = '''
<html>
<head><title>Test</title></head>
<body>
  <h1 class="p-novel__title">テスト小説タイトル</h1>
  <div class="p-eplist">
    <a href="/n9669bk/1/" class="p-eplist__subtitle">第一話 始まり</a>
    <a href="/n9669bk/2/" class="p-eplist__subtitle">第二話 展開</a>
    <a href="/n9669bk/3/" class="p-eplist__subtitle">第三話 結末</a>
  </div>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://ncode.syosetu.com/n9669bk/');
      final index = site.parseIndex(html, baseUrl);

      expect(index.title, 'テスト小説タイトル');
      expect(index.episodes.length, 3);
      expect(index.episodes[0].index, 1);
      expect(index.episodes[0].title, '第一話 始まり');
      expect(index.episodes[0].url.toString(),
          'https://ncode.syosetu.com/n9669bk/1/');
      expect(index.episodes[2].index, 3);
      expect(index.episodes[2].title, '第三話 結末');
    });

    test('uses fallback title selector', () {
      const html = '''
<html>
<body>
  <h1>フォールバックタイトル</h1>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://ncode.syosetu.com/n9669bk/');
      final index = site.parseIndex(html, baseUrl);

      expect(index.title, 'フォールバックタイトル');
      expect(index.episodes, isEmpty);
    });

    test('returns empty episodes when no links found', () {
      const html = '''
<html>
<body>
  <h1 class="p-novel__title">タイトルのみ</h1>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://ncode.syosetu.com/n9669bk/');
      final index = site.parseIndex(html, baseUrl);

      expect(index.title, 'タイトルのみ');
      expect(index.episodes, isEmpty);
    });

    test('extracts bodyContent for short story (no episode links, body text present)', () {
      const html = '''
<html>
<body>
  <h1 class="p-novel__title">短編小説タイトル</h1>
  <div class="js-novel-text p-novel__text">
    <p>短編の本文です。</p>
    <p>二段落目です。</p>
  </div>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://ncode.syosetu.com/n5983ls/');
      final index = site.parseIndex(html, baseUrl);

      expect(index.title, '短編小説タイトル');
      expect(index.episodes, isEmpty);
      expect(index.bodyContent, isNotNull);
      expect(index.bodyContent, contains('短編の本文です。'));
      expect(index.bodyContent, contains('二段落目です。'));
    });

    test('returns null bodyContent when no episodes and no body text', () {
      const html = '''
<html>
<body>
  <h1 class="p-novel__title">タイトルのみ</h1>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://ncode.syosetu.com/n9669bk/');
      final index = site.parseIndex(html, baseUrl);

      expect(index.title, 'タイトルのみ');
      expect(index.episodes, isEmpty);
      expect(index.bodyContent, isNull);
    });

    test('returns null bodyContent for multi-episode novel', () {
      const html = '''
<html>
<body>
  <h1 class="p-novel__title">長編小説</h1>
  <div class="p-eplist">
    <a href="/n9669bk/1/" class="p-eplist__subtitle">第一話</a>
    <a href="/n9669bk/2/" class="p-eplist__subtitle">第二話</a>
  </div>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://ncode.syosetu.com/n9669bk/');
      final index = site.parseIndex(html, baseUrl);

      expect(index.title, '長編小説');
      expect(index.episodes.length, 2);
      expect(index.bodyContent, isNull);
    });

    test('extracts revision date as updatedAt when episode has been revised', () {
      const html = '''
<html>
<body>
  <h1 class="p-novel__title">テスト小説</h1>
  <div class="p-eplist__sublist">
    <a href="/n9669bk/1/" class="p-eplist__subtitle">プロローグ</a>
    <div class="p-eplist__update">
      2012/11/22 17:00
      <span title="2013/11/27 13:06 改稿">（<u>改</u>）</span>
    </div>
  </div>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://ncode.syosetu.com/n9669bk/');
      final index = site.parseIndex(html, baseUrl);

      expect(index.episodes.length, 1);
      expect(index.episodes[0].updatedAt, '2013/11/27 13:06');
    });

    test('extracts publish date as updatedAt when episode has no revision', () {
      const html = '''
<html>
<body>
  <h1 class="p-novel__title">テスト小説</h1>
  <div class="p-eplist__sublist">
    <a href="/n9669bk/1/" class="p-eplist__subtitle">第一話</a>
    <div class="p-eplist__update">
      2012/11/22 17:00
    </div>
  </div>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://ncode.syosetu.com/n9669bk/');
      final index = site.parseIndex(html, baseUrl);

      expect(index.episodes.length, 1);
      expect(index.episodes[0].updatedAt, '2012/11/22 17:00');
    });

    test('sets updatedAt to null when no update date element exists', () {
      const html = '''
<html>
<body>
  <h1 class="p-novel__title">テスト小説</h1>
  <div class="p-eplist">
    <a href="/n9669bk/1/" class="p-eplist__subtitle">第一話</a>
  </div>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://ncode.syosetu.com/n9669bk/');
      final index = site.parseIndex(html, baseUrl);

      expect(index.episodes.length, 1);
      expect(index.episodes[0].updatedAt, isNull);
    });
  });

  group('siteType', () {
    test('returns narou', () {
      expect(site.siteType, 'narou');
    });
  });

  group('extractNovelId', () {
    test('extracts ncode from standard URL', () {
      final url = Uri.parse('https://ncode.syosetu.com/n9669bk/');
      expect(site.extractNovelId(url), 'n9669bk');
    });

    test('extracts ncode from URL with episode path', () {
      final url = Uri.parse('https://ncode.syosetu.com/n9669bk/1/');
      expect(site.extractNovelId(url), 'n9669bk');
    });

    test('extracts ncode from novel18 URL', () {
      final url = Uri.parse('https://novel18.syosetu.com/n1234ab/');
      expect(site.extractNovelId(url), 'n1234ab');
    });

    test('throws ArgumentError for URL without ncode', () {
      final url = Uri.parse('https://syosetu.com/');
      expect(() => site.extractNovelId(url), throwsArgumentError);
    });
  });

  group('parseEpisode', () {
    test('extracts body text from episode page', () {
      const html = '''
<html>
<body>
  <div class="js-novel-text p-novel__text">
    <p>これは第一段落です。</p>
    <p>これは第二段落です。</p>
  </div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('これは第一段落です。'));
      expect(text, contains('これは第二段落です。'));
    });

    test('preserves ruby tags', () {
      const html = '''
<html>
<body>
  <div class="js-novel-text p-novel__text">
    <p><ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>のテスト</p>
  </div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('<ruby>'));
      expect(text, contains('漢字'));
      expect(text, contains('<rt>かんじ</rt>'));
    });

    test('converts br tags to newlines', () {
      const html = '''
<html>
<body>
  <div class="js-novel-text p-novel__text">
    <p>一行目<br>二行目</p>
  </div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('一行目\n二行目'));
    });

    test('joins paragraphs with single newline', () {
      const html = '''
<html>
<body>
  <div class="js-novel-text p-novel__text">
    <p>第一段落です。</p>
    <p>第二段落です。</p>
    <p>第三段落です。</p>
  </div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, equals('第一段落です。\n第二段落です。\n第三段落です。'));
    });

    test('preserves blank lines from empty p tags with br', () {
      const html = '''
<html>
<body>
  <div class="js-novel-text p-novel__text">
    <p>場面Aの最後。</p>
    <p><br /></p>
    <p>場面Bの最初。</p>
  </div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, equals('場面Aの最後。\n\n場面Bの最初。'));
    });

    test('preserves multiple consecutive blank lines', () {
      const html = '''
<html>
<body>
  <div class="js-novel-text p-novel__text">
    <p>場面A。</p>
    <p><br /></p>
    <p><br /></p>
    <p>場面B。</p>
  </div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, equals('場面A。\n\n\n場面B。'));
    });

    test('returns empty string when no body found', () {
      const html = '''
<html>
<body>
  <div class="unrelated">何もない</div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, isEmpty);
    });

    test('uses fallback selector', () {
      const html = '''
<html>
<body>
  <div id="novel_honbun">
    <p>フォールバック本文</p>
  </div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('フォールバック本文'));
    });
  });
}
