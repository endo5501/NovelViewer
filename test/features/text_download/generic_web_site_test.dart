import 'dart:convert';

import 'package:euc/euc.dart';
import 'package:euc/jis.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/text_download/data/sites/generic_web_site.dart';

void main() {
  late GenericWebSite site;

  setUp(() {
    site = GenericWebSite();
  });

  group('siteType', () {
    test('returns web', () {
      expect(site.siteType, 'web');
    });
  });

  group('canHandle', () {
    test('accepts https URL', () {
      expect(site.canHandle(Uri.parse('https://example.com/article')), isTrue);
    });

    test('accepts http URL', () {
      expect(site.canHandle(Uri.parse('http://example.com/article')), isTrue);
    });

    test('rejects non-web scheme', () {
      expect(site.canHandle(Uri.parse('file:///tmp/a.html')), isFalse);
    });
  });

  group('normalizeUrl', () {
    test('preserves the http scheme (http-only sites)', () {
      expect(
        site.normalizeUrl(Uri.parse('http://example.com/a')).toString(),
        'http://example.com/a',
      );
    });

    test('drops fragment', () {
      expect(
        site.normalizeUrl(Uri.parse('https://example.com/a#section')).toString(),
        'https://example.com/a',
      );
    });
  });

  group('parseEpisode - noise removal', () {
    test('removes script/style/nav/header/footer/aside/form', () {
      const html = '''
<html>
<body>
  <header><a href="/">サイト名</a></header>
  <nav><a href="/x">メニュー項目</a></nav>
  <article>
    <p>これが本物の記事本文です。十分な長さを持っています。</p>
  </article>
  <aside><a href="/y">関連記事リンク</a></aside>
  <footer>フッターのコピーライト表記</footer>
  <script>console.log('noise');</script>
  <style>.x{color:red}</style>
  <form><input name="q"></form>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('記事本文'));
      expect(text, isNot(contains('メニュー項目')));
      expect(text, isNot(contains('フッター')));
      expect(text, isNot(contains('関連記事リンク')));
      expect(text, isNot(contains('console.log')));
    });
  });

  group('parseEpisode - selection order', () {
    test('prefers semantic <article> over CMS container', () {
      const html = '''
<html>
<body>
  <div class="entry-content"><p>CMSコンテナの本文。これは選ばれないべき。</p></div>
  <article><p>セマンティック要素の本文。こちらが優先される。</p></article>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('セマンティック要素の本文'));
      expect(text, isNot(contains('CMSコンテナの本文')));
    });

    test('falls back to CMS container when no semantic element', () {
      const html = '''
<html>
<body>
  <div class="sidebar"><a href="/a">広告</a></div>
  <div class="entry-content"><p>CMS定番コンテナに入った記事本文です。</p></div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('CMS定番コンテナに入った記事本文'));
      expect(text, isNot(contains('広告')));
    });

    test('falls back to text density when no semantic or CMS container', () {
      const html = '''
<html>
<body>
  <div class="links">
    <a href="/1">リンク1</a><a href="/2">リンク2</a><a href="/3">リンク3</a>
  </div>
  <div class="main">
    <p>密度フォールバックで選ばれるべき本文段落その一。</p>
    <p>密度フォールバックで選ばれるべき本文段落その二。</p>
  </div>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('本文段落その一'));
      expect(text, contains('本文段落その二'));
      expect(text, isNot(contains('リンク1')));
    });
  });

  group('parseEpisode - text formatting', () {
    test('preserves ruby tags', () {
      const html = '''
<html>
<body>
  <article>
    <p><ruby><rb>銀河</rb><rp>（</rp><rt>ぎんが</rt><rp>）</rp></ruby>の夜の物語です。</p>
  </article>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('<ruby>'));
      expect(text, contains('<rt>ぎんが</rt>'));
    });

    test('converts br to newline', () {
      const html = '''
<html>
<body>
  <article><p>一行目<br>二行目の文章がここに続きます。</p></article>
</body>
</html>
''';
      final text = site.parseEpisode(html);

      expect(text, contains('一行目\n二行目'));
    });
  });

  group('parseIndex - title', () {
    Uri base() => Uri.parse('https://example.com/article');
    const body = '<article><p>'
        '記事本文が十分な長さで入っています。これはタイトル判定用のダミー本文。'
        '</p></article>';

    test('prefers og:title', () {
      const html = '''
<html>
<head>
  <title>記事タイトル - ブログ名</title>
  <meta property="og:title" content="記事タイトル">
</head>
<body>$body</body>
</html>
''';
      final index = site.parseIndex(html, base());
      expect(index.title, '記事タイトル');
    });

    test('falls back to h1 when no og:title', () {
      const html = '''
<html>
<head><title>記事タイトル - ブログ名</title></head>
<body><h1>見出しタイトル</h1>$body</body>
</html>
''';
      final index = site.parseIndex(html, base());
      expect(index.title, '見出しタイトル');
    });

    test('falls back to title tag when no og:title or h1', () {
      const html = '''
<html>
<head><title>タイトルタグの値</title></head>
<body>$body</body>
</html>
''';
      final index = site.parseIndex(html, base());
      expect(index.title, 'タイトルタグの値');
    });
  });

  group('parseIndex - empty/short guard', () {
    Uri base() => Uri.parse('https://example.com/article');

    test('drops bodyContent to null when extracted text is too short', () {
      const html = '<html><body><article><p>短い。</p></article></body></html>';
      final index = site.parseIndex(html, base());
      expect(index.bodyContent, isNull);
      expect(index.episodes, isEmpty);
    });

    test('keeps bodyContent when extracted text meets the minimum length', () {
      final longText = 'あ' * GenericWebSite.minBodyLength;
      final html = '<html><body><article><p>$longText</p></article></body></html>';
      final index = site.parseIndex(html, base());
      expect(index.bodyContent, isNotNull);
      expect(index.bodyContent, contains(longText));
    });
  });

  group('decodeBody - charset detection', () {
    http.Response responseWith(List<int> bytes, {String? contentType}) {
      return http.Response.bytes(
        bytes,
        200,
        headers: contentType != null ? {'content-type': contentType} : const {},
      );
    }

    test('uses charset from Content-Type header', () {
      const text = '見出しと本文のサンプルテキスト';
      final bytes = ShiftJIS().encode(text);
      final response = responseWith(bytes,
          contentType: 'text/html; charset=Shift_JIS');
      expect(site.decodeBody(response), text);
    });

    test('uses meta charset for Shift_JIS when header has none', () {
      const text = '昔ながらの個人ブログの本文';
      final inner = ShiftJIS().encode(text);
      const prefix = '<html><head><meta charset="Shift_JIS"></head><body><p>';
      const suffix = '</p></body></html>';
      final bytes = <int>[
        ...prefix.codeUnits,
        ...inner,
        ...suffix.codeUnits,
      ];
      final response = responseWith(bytes, contentType: 'text/html');
      expect(site.decodeBody(response), contains(text));
    });

    test('decodes EUC-JP via meta charset', () {
      const text = 'EUCで書かれた段落';
      final inner = EucJP().encode(text);
      const prefix = '<html><head><meta charset="euc-jp"></head><body><p>';
      const suffix = '</p></body></html>';
      final bytes = <int>[
        ...prefix.codeUnits,
        ...inner,
        ...suffix.codeUnits,
      ];
      final response = responseWith(bytes);
      expect(site.decodeBody(response), contains(text));
    });

    test('falls back to UTF-8 when no charset is declared', () {
      const text = 'UTF-8の本文テキスト';
      final response = responseWith(utf8.encode('<p>$text</p>'));
      expect(site.decodeBody(response), contains(text));
    });
  });
}
