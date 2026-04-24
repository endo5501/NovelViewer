import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/sites/kakuyomu_site.dart';

String _buildApolloHtml({
  required Map<String, Object?> apolloState,
  String? extraBodyHtml,
}) {
  final encoded = jsonEncode({
    'props': {
      'pageProps': {
        '__APOLLO_STATE__': apolloState,
      },
    },
  });
  final body = extraBodyHtml ?? '';
  return '<html><head><title>test</title></head><body>$body'
      '<script id="__NEXT_DATA__" type="application/json">$encoded</script>'
      '</body></html>';
}

Map<String, Object?> _apolloState({
  required String workId,
  required String workTitle,
  required List<Map<String, Object?>> chapters,
  bool includeRootQuery = true,
}) {
  final state = <String, Object?>{};

  if (includeRootQuery) {
    state['ROOT_QUERY'] = {
      '__typename': 'Query',
      'work({"id":"$workId"})': {'__ref': 'Work:$workId'},
    };
  }

  final tocRefs = <Map<String, String>>[];
  for (final chapter in chapters) {
    final chapterId = chapter['id'] as String;
    final chapterKey = 'TableOfContentsChapter:$chapterId';
    final episodes = chapter['episodes'] as List<Map<String, Object?>>;
    final episodeRefs = <Map<String, String>>[];
    for (final ep in episodes) {
      final epId = ep['id'] as String;
      final epKey = 'Episode:$epId';
      episodeRefs.add({'__ref': epKey});
      state[epKey] = {
        '__typename': 'Episode',
        'id': epId,
        'title': ep['title'],
        if (ep.containsKey('publishedAt')) 'publishedAt': ep['publishedAt'],
      };
    }
    state[chapterKey] = {
      '__typename': 'TableOfContentsChapter',
      'id': chapterId,
      'episodeUnions': episodeRefs,
    };
    tocRefs.add({'__ref': chapterKey});
  }

  state['Work:$workId'] = {
    '__typename': 'Work',
    'id': workId,
    'title': workTitle,
    'tableOfContentsV2': tocRefs,
  };

  return state;
}

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

  group('parseIndex (Apollo state)', () {
    const workId = '12345';
    final baseUrl = Uri.parse('https://kakuyomu.jp/works/$workId');

    test('extracts all episodes flattened across chapters with continuous index',
        () {
      final apollo = _apolloState(
        workId: workId,
        workTitle: 'テスト小説',
        chapters: [
          {
            'id': 'c1',
            'episodes': [
              {
                'id': 'e1',
                'title': '第1話 はじまり',
                'publishedAt': '2025-01-01T00:00:00.000Z',
              },
              {
                'id': 'e2',
                'title': '第2話 つづき',
                'publishedAt': '2025-01-02T00:00:00.000Z',
              },
            ],
          },
          {
            'id': 'c2',
            'episodes': [
              {
                'id': 'e3',
                'title': '第3話 別章',
                'publishedAt': '2025-01-03T00:00:00.000Z',
              },
              {
                'id': 'e4',
                'title': '第4話 終章',
                'publishedAt': '2025-01-04T00:00:00.000Z',
              },
            ],
          },
        ],
      );
      final html = _buildApolloHtml(apolloState: apollo);

      final index = site.parseIndex(html, baseUrl);

      expect(index.title, 'テスト小説');
      expect(index.episodes, hasLength(4));
      expect(index.episodes.map((e) => e.index), [1, 2, 3, 4]);
      expect(index.episodes.map((e) => e.title), [
        '第1話 はじまり',
        '第2話 つづき',
        '第3話 別章',
        '第4話 終章',
      ]);
    });

    test('Episode.title comes from Apollo title field, not DOM <a> text', () {
      final apollo = _apolloState(
        workId: workId,
        workTitle: 'テスト小説',
        chapters: [
          {
            'id': 'c1',
            'episodes': [
              {
                'id': 'e1',
                'title': '第1話 「実タイトル」',
                'publishedAt': '2025-01-01T00:00:00.000Z',
              },
            ],
          },
        ],
      );
      const ctaHtml =
          '<a href="/works/12345/episodes/e1">1話目から読む</a>';
      final html = _buildApolloHtml(
        apolloState: apollo,
        extraBodyHtml: ctaHtml,
      );

      final index = site.parseIndex(html, baseUrl);

      expect(index.episodes, hasLength(1));
      expect(index.episodes[0].title, '第1話 「実タイトル」');
    });

    test('Episode.url is composed from baseUrl host and Episode.id', () {
      final apollo = _apolloState(
        workId: workId,
        workTitle: 'テスト小説',
        chapters: [
          {
            'id': 'c1',
            'episodes': [
              {
                'id': '999888',
                'title': '第1話',
                'publishedAt': '2025-01-01T00:00:00.000Z',
              },
            ],
          },
        ],
      );
      final html = _buildApolloHtml(apolloState: apollo);

      final index = site.parseIndex(html, baseUrl);

      expect(index.episodes[0].url.toString(),
          'https://kakuyomu.jp/works/$workId/episodes/999888');
    });

    test('Episode.updatedAt equals Apollo Episode.publishedAt', () {
      const publishedAt = '2025-03-10T12:34:56.000Z';
      final apollo = _apolloState(
        workId: workId,
        workTitle: 'タイトル',
        chapters: [
          {
            'id': 'c1',
            'episodes': [
              {'id': 'e1', 'title': '第1話', 'publishedAt': publishedAt},
            ],
          },
        ],
      );
      final html = _buildApolloHtml(apolloState: apollo);

      final index = site.parseIndex(html, baseUrl);

      expect(index.episodes[0].updatedAt, publishedAt);
    });

    test('Episode.updatedAt is null when publishedAt missing', () {
      final apollo = _apolloState(
        workId: workId,
        workTitle: 'タイトル',
        chapters: [
          {
            'id': 'c1',
            'episodes': [
              {'id': 'e1', 'title': '第1話'},
            ],
          },
        ],
      );
      final html = _buildApolloHtml(apolloState: apollo);

      final index = site.parseIndex(html, baseUrl);

      expect(index.episodes[0].updatedAt, isNull);
    });

    test('Episode.updatedAt is null when publishedAt explicitly null', () {
      final apollo = _apolloState(
        workId: workId,
        workTitle: 'タイトル',
        chapters: [
          {
            'id': 'c1',
            'episodes': [
              {'id': 'e1', 'title': '第1話', 'publishedAt': null},
            ],
          },
        ],
      );
      final html = _buildApolloHtml(apolloState: apollo);

      final index = site.parseIndex(html, baseUrl);

      expect(index.episodes[0].updatedAt, isNull);
    });

    test('NovelIndex.title comes from Work.title', () {
      final apollo = _apolloState(
        workId: workId,
        workTitle: 'カクヨムから取った正しいタイトル',
        chapters: [
          {
            'id': 'c1',
            'episodes': [
              {
                'id': 'e1',
                'title': '第1話',
                'publishedAt': '2025-01-01T00:00:00.000Z',
              },
            ],
          },
        ],
      );
      const irrelevantHeading = '<h1 id="workTitle">DOM上の異なるタイトル</h1>';
      final html = _buildApolloHtml(
        apolloState: apollo,
        extraBodyHtml: irrelevantHeading,
      );

      final index = site.parseIndex(html, baseUrl);

      expect(index.title, 'カクヨムから取った正しいタイトル');
    });

    test('throws ArgumentError when __NEXT_DATA__ script is missing', () {
      const html = '<html><body><h1>no script</h1></body></html>';

      expect(() => site.parseIndex(html, baseUrl), throwsArgumentError);
    });

    test('throws ArgumentError when __NEXT_DATA__ JSON is malformed', () {
      const html =
          '<html><body><script id="__NEXT_DATA__" type="application/json">'
          'this is not json'
          '</script></body></html>';

      expect(() => site.parseIndex(html, baseUrl), throwsArgumentError);
    });

    test('throws ArgumentError when __APOLLO_STATE__ is missing', () {
      const json = '{"props":{"pageProps":{}}}';
      const html =
          '<html><body><script id="__NEXT_DATA__" type="application/json">'
          '$json'
          '</script></body></html>';

      expect(() => site.parseIndex(html, baseUrl), throwsArgumentError);
    });

    test('throws ArgumentError when Work entity cannot be resolved', () {
      // Apollo state present but Work:<workId> missing
      final apollo = <String, Object?>{
        'ROOT_QUERY': {
          '__typename': 'Query',
          'work({"id":"$workId"})': {'__ref': 'Work:$workId'},
        },
        // Note: no Work:12345 entry
      };
      final html = _buildApolloHtml(apolloState: apollo);

      expect(() => site.parseIndex(html, baseUrl), throwsArgumentError);
    });

    test('returns empty episodes when tableOfContentsV2 is empty', () {
      final apollo = <String, Object?>{
        'ROOT_QUERY': {
          '__typename': 'Query',
          'work({"id":"$workId"})': {'__ref': 'Work:$workId'},
        },
        'Work:$workId': {
          '__typename': 'Work',
          'id': workId,
          'title': '空のTOC',
          'tableOfContentsV2': <Map<String, String>>[],
        },
      };
      final html = _buildApolloHtml(apolloState: apollo);

      final index = site.parseIndex(html, baseUrl);

      expect(index.title, '空のTOC');
      expect(index.episodes, isEmpty);
    });

    test('regression: "1話目から読む" CTA in DOM does not affect ep1 title', () {
      final apollo = _apolloState(
        workId: workId,
        workTitle: 'テスト小説',
        chapters: [
          {
            'id': 'c1',
            'episodes': [
              {
                'id': 'e1',
                'title': '第1話 「お願いだ……〈レイダス〉、動いてくれよ！」',
                'publishedAt': '2025-01-27T17:36:06.000Z',
              },
              {
                'id': 'e2',
                'title': '第2話 つづき',
                'publishedAt': '2025-01-31T03:00:30.000Z',
              },
            ],
          },
        ],
      );
      // Mimic real Kakuyomu page: CTA + latest preview links pointing to same URLs
      const ctaAndPreview = '''
<a href="/works/12345/episodes/e1">1話目から読む</a>
<a href="/works/12345/episodes/e1">第1話「お願いだ…」</a>
<a href="/works/12345/episodes/e2">第2話「つづき」</a>
''';
      final html = _buildApolloHtml(
        apolloState: apollo,
        extraBodyHtml: ctaAndPreview,
      );

      final index = site.parseIndex(html, baseUrl);

      expect(index.episodes, hasLength(2));
      expect(index.episodes[0].title,
          '第1話 「お願いだ……〈レイダス〉、動いてくれよ！」');
      expect(index.episodes[0].url.toString(),
          'https://kakuyomu.jp/works/$workId/episodes/e1');
      expect(index.episodes[1].title, '第2話 つづき');
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
