import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/sites/aozora_site.dart';

void main() {
  late AozoraSite site;

  setUp(() {
    site = AozoraSite();
  });

  group('siteType', () {
    test('returns aozora', () {
      expect(site.siteType, 'aozora');
    });
  });

  group('canHandle', () {
    test('returns true for www.aozora.gr.jp HTML file URL', () {
      expect(
        site.canHandle(Uri.parse(
            'https://www.aozora.gr.jp/cards/001779/files/57105_59659.html')),
        isTrue,
      );
    });

    test('returns false for card page URL', () {
      expect(
        site.canHandle(Uri.parse(
            'https://www.aozora.gr.jp/cards/001779/card57105.html')),
        isFalse,
      );
    });

    test('returns false for top page URL', () {
      expect(
        site.canHandle(Uri.parse('https://www.aozora.gr.jp/')),
        isFalse,
      );
    });

    test('returns false for other sites', () {
      expect(
        site.canHandle(Uri.parse('https://ncode.syosetu.com/n9669bk/')),
        isFalse,
      );
    });
  });

  group('extractNovelId', () {
    test('extracts filename without extension from URL', () {
      final url = Uri.parse(
          'https://www.aozora.gr.jp/cards/001779/files/57105_59659.html');
      expect(site.extractNovelId(url), '57105_59659');
    });

    test('throws ArgumentError for URL without files path', () {
      final url = Uri.parse('https://www.aozora.gr.jp/');
      expect(() => site.extractNovelId(url), throwsArgumentError);
    });
  });

  group('normalizeUrl', () {
    test('preserves URL as-is', () {
      final url = Uri.parse(
          'https://www.aozora.gr.jp/cards/001779/files/57105_59659.html');
      final normalized = site.normalizeUrl(url);
      expect(normalized.toString(),
          'https://www.aozora.gr.jp/cards/001779/files/57105_59659.html');
    });
  });

  group('requestHeaders', () {
    test('returns empty map', () {
      final url = Uri.parse(
          'https://www.aozora.gr.jp/cards/001779/files/57105_59659.html');
      expect(site.requestHeaders(url), isEmpty);
    });
  });

  group('parseIndex', () {
    test('extracts title from title tag', () {
      const html = '''
<html>
<head><title>銀河鉄道の夜 宮沢賢治</title></head>
<body>
  <div class="main_text">
    <p>本文です。</p>
  </div>
</body>
</html>
''';
      final baseUrl = Uri.parse(
          'https://www.aozora.gr.jp/cards/000081/files/456_15050.html');
      final index = site.parseIndex(html, baseUrl);

      expect(index.title, '銀河鉄道の夜 宮沢賢治');
    });

    test('returns empty episodes list', () {
      const html = '''
<html>
<head><title>テスト作品 テスト著者</title></head>
<body>
  <div class="main_text">
    <p>本文。</p>
  </div>
</body>
</html>
''';
      final baseUrl = Uri.parse(
          'https://www.aozora.gr.jp/cards/000081/files/456_15050.html');
      final index = site.parseIndex(html, baseUrl);

      expect(index.episodes, isEmpty);
    });

    test('extracts bodyContent from main_text div', () {
      const html = '''
<html>
<head><title>テスト作品 テスト著者</title></head>
<body>
  <div class="main_text">
    <p>第一段落です。</p>
    <p>第二段落です。</p>
  </div>
</body>
</html>
''';
      final baseUrl = Uri.parse(
          'https://www.aozora.gr.jp/cards/000081/files/456_15050.html');
      final index = site.parseIndex(html, baseUrl);

      expect(index.bodyContent, isNotNull);
      expect(index.bodyContent, contains('第一段落です。'));
      expect(index.bodyContent, contains('第二段落です。'));
    });

    test('returns null bodyContent when no main_text div', () {
      const html = '''
<html>
<head><title>テスト</title></head>
<body>
  <div class="other">何もない</div>
</body>
</html>
''';
      final baseUrl = Uri.parse(
          'https://www.aozora.gr.jp/cards/000081/files/456_15050.html');
      final index = site.parseIndex(html, baseUrl);

      expect(index.bodyContent, isNull);
    });
  });

  group('parseEpisode', () {
    test('extracts body text from main_text div', () {
      const html = '''
<html>
<body>
  <div class="main_text">
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
  <div class="main_text">
    <p><ruby><rb>銀河</rb><rp>（</rp><rt>ぎんが</rt><rp>）</rp></ruby>の夜</p>
  </div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('<ruby>'));
      expect(text, contains('銀河'));
      expect(text, contains('<rt>ぎんが</rt>'));
    });

    test('converts br tags to newlines', () {
      const html = '''
<html>
<body>
  <div class="main_text">
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
  <div class="main_text">
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
  <div class="main_text">
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

    test('returns empty string when no main_text found', () {
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
  });
}
