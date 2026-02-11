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
