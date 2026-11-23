import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

void main() {
  final registry = NovelSiteRegistry();
  bool matches(String url, String folderName) =>
      urlPointsToNovelFolder(url, folderName, registry: registry);

  group('a url of a supported site that leads to the folder passes', () {
    test('narou', () {
      expect(
        matches('https://ncode.syosetu.com/n1234ab/', 'narou_n1234ab'),
        isTrue,
      );
    });

    test('narou R18', () {
      expect(
        matches('https://novel18.syosetu.com/n1234ab/', 'narou_n1234ab'),
        isTrue,
      );
    });

    test('kakuyomu', () {
      expect(
        matches(
          'https://kakuyomu.jp/works/1177354054881162325',
          'kakuyomu_1177354054881162325',
        ),
        isTrue,
      );
    });

    test('hameln', () {
      expect(
        matches('https://syosetu.org/novel/123456/', 'hameln_123456'),
        isTrue,
      );
    });

    test('aozora', () {
      expect(
        matches(
          'https://www.aozora.gr.jp/cards/001779/files/57105_59659.html',
          'aozora_57105_59659',
        ),
        isTrue,
      );
    });

    test('a url before normalization still leads to the same folder', () {
      expect(
        matches('https://ncode.syosetu.com/n1234ab/5/', 'narou_n1234ab'),
        isTrue,
      );
    });
  });

  group('fails', () {
    test('a url of another novel', () {
      expect(
        matches('https://ncode.syosetu.com/n9999zz/', 'narou_n1234ab'),
        isFalse,
      );
    });

    test('a url of another site with the same id', () {
      expect(
        matches('https://syosetu.org/novel/123456/', 'kakuyomu_123456'),
        isFalse,
      );
    });

    test('a generic web url', () {
      expect(matches('https://example.com/article', 'web_article'), isFalse);
    });

    test('a url no site handles', () {
      expect(
        matches('ftp://ncode.syosetu.com/n1234ab/', 'narou_n1234ab'),
        isFalse,
      );
    });

    test('a url the site cannot take an id from', () {
      expect(matches('https://ncode.syosetu.com/', 'narou_n1234ab'), isFalse);
    });

    test('text that is not a url', () {
      expect(matches('not a url', 'narou_n1234ab'), isFalse);
      expect(matches('', 'narou_n1234ab'), isFalse);
    });
  });

  test('novelFolderName joins the site type and the novel id', () {
    final url = Uri.parse('https://ncode.syosetu.com/n9669bk/');
    final site = registry.findSite(url)!;
    expect(novelFolderName(site, site.normalizeUrl(url)), 'narou_n9669bk');
  });
}
