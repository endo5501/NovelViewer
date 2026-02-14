import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/sites/kakuyomu_site.dart';

void main() {
  late KakuyomuSite site;

  setUp(() {
    site = KakuyomuSite();
  });

  group('canHandle', () {
    test('returns true for kakuyomu.jp', () {
      expect(
        site.canHandle(
            Uri.parse('https://kakuyomu.jp/works/1177354054881162325')),
        isTrue,
      );
    });

    test('returns false for syosetu.com', () {
      expect(
        site.canHandle(Uri.parse('https://ncode.syosetu.com/n9669bk/')),
        isFalse,
      );
    });
  });

  group('normalizeUrl', () {
    test('normalizes URL with episode path', () {
      final url = Uri.parse(
          'https://kakuyomu.jp/works/1177354054881162325/episodes/999');
      final normalized = site.normalizeUrl(url);
      expect(normalized.toString(),
          'https://kakuyomu.jp/works/1177354054881162325');
    });

    test('keeps already normalized URL', () {
      final url =
          Uri.parse('https://kakuyomu.jp/works/1177354054881162325');
      final normalized = site.normalizeUrl(url);
      expect(normalized.toString(),
          'https://kakuyomu.jp/works/1177354054881162325');
    });
  });

  group('siteType', () {
    test('returns kakuyomu', () {
      expect(site.siteType, 'kakuyomu');
    });
  });

  group('extractNovelId', () {
    test('extracts work ID from standard URL', () {
      final url =
          Uri.parse('https://kakuyomu.jp/works/1177354054881162325');
      expect(site.extractNovelId(url), '1177354054881162325');
    });

    test('extracts work ID from URL with episode path', () {
      final url = Uri.parse(
          'https://kakuyomu.jp/works/1177354054881162325/episodes/999');
      expect(site.extractNovelId(url), '1177354054881162325');
    });

    test('throws ArgumentError for URL without work ID', () {
      final url = Uri.parse('https://kakuyomu.jp/');
      expect(() => site.extractNovelId(url), throwsArgumentError);
    });
  });

  group('parseIndex', () {
    test('extracts title and episodes from index page', () {
      const html = '''
<html>
<head><title>Test</title></head>
<body>
  <h1 id="workTitle">カクヨムテスト小説</h1>
  <div class="widget-toc">
    <a href="/works/123/episodes/1">第1話 始まり</a>
    <a href="/works/123/episodes/2">第2話 中盤</a>
    <a href="/works/123/episodes/3">第3話 終わり</a>
  </div>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://kakuyomu.jp/works/123');
      final index = site.parseIndex(html, baseUrl);

      expect(index.title, 'カクヨムテスト小説');
      expect(index.episodes.length, 3);
      expect(index.episodes[0].index, 1);
      expect(index.episodes[0].title, '第1話 始まり');
      expect(index.episodes[0].url.toString(),
          'https://kakuyomu.jp/works/123/episodes/1');
      expect(index.episodes[2].index, 3);
      expect(index.episodes[2].title, '第3話 終わり');
    });

    test('extracts updatedAt from time element dateTime attribute', () {
      const html = '''
<html>
<body>
  <h1 id="workTitle">カクヨムテスト小説</h1>
  <a href="/works/123/episodes/1">
    <div>第1話 始まり</div>
    <time dateTime="2022-06-02T05:58:54.000Z">2022年6月2日</time>
  </a>
  <a href="/works/123/episodes/2">
    <div>第2話 中盤</div>
    <time dateTime="2023-01-15T10:30:00.000Z">2023年1月15日</time>
  </a>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://kakuyomu.jp/works/123');
      final index = site.parseIndex(html, baseUrl);

      expect(index.episodes.length, 2);
      expect(index.episodes[0].updatedAt, '2022-06-02T05:58:54.000Z');
      expect(index.episodes[1].updatedAt, '2023-01-15T10:30:00.000Z');
    });

    test('sets updatedAt to null when no time element exists', () {
      const html = '''
<html>
<body>
  <h1 id="workTitle">カクヨムテスト小説</h1>
  <a href="/works/123/episodes/1">第1話 始まり</a>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://kakuyomu.jp/works/123');
      final index = site.parseIndex(html, baseUrl);

      expect(index.episodes.length, 1);
      expect(index.episodes[0].updatedAt, isNull);
    });

    test('uses fallback title selector', () {
      const html = '''
<html>
<body>
  <h1>フォールバックタイトル</h1>
</body>
</html>
''';
      final baseUrl = Uri.parse('https://kakuyomu.jp/works/123');
      final index = site.parseIndex(html, baseUrl);

      expect(index.title, 'フォールバックタイトル');
      expect(index.episodes, isEmpty);
    });
  });

  group('parseEpisode', () {
    test('extracts body text from episode page', () {
      const html = '''
<html>
<body>
  <div class="widget-episodeBody__content">
    <p>これはカクヨムの第一段落です。</p>
    <p>これはカクヨムの第二段落です。</p>
  </div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('これはカクヨムの第一段落です。'));
      expect(text, contains('これはカクヨムの第二段落です。'));
    });

    test('preserves ruby tags', () {
      const html = '''
<html>
<body>
  <div class="widget-episodeBody__content">
    <p><ruby>魔法<rp>(</rp><rt>まほう</rt><rp>)</rp></ruby>を使った</p>
  </div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('<ruby>'));
      expect(text, contains('魔法'));
      expect(text, contains('<rt>まほう</rt>'));
    });

    test('converts br tags to newlines', () {
      const html = '''
<html>
<body>
  <div class="widget-episodeBody__content">
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
  <div class="widget-episodeBody__content">
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
  <div class="widget-episodeBody__content">
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
  <div class="widget-episodeBody__content">
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
  <div class="widget-episodeBody">
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
