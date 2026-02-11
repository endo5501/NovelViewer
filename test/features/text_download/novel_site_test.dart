import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

void main() {
  group('Episode', () {
    test('creates Episode with correct fields', () {
      final episode = Episode(
        index: 1,
        title: 'プロローグ',
        url: Uri.parse('https://ncode.syosetu.com/n9669bk/1/'),
      );

      expect(episode.index, 1);
      expect(episode.title, 'プロローグ');
      expect(episode.url.toString(), 'https://ncode.syosetu.com/n9669bk/1/');
    });
  });

  group('NovelIndex', () {
    test('creates NovelIndex with title and episodes', () {
      final episodes = [
        Episode(
          index: 1,
          title: '第一話',
          url: Uri.parse('https://ncode.syosetu.com/n9669bk/1/'),
        ),
        Episode(
          index: 2,
          title: '第二話',
          url: Uri.parse('https://ncode.syosetu.com/n9669bk/2/'),
        ),
      ];

      final index = NovelIndex(
        title: 'テスト小説',
        episodes: episodes,
      );

      expect(index.title, 'テスト小説');
      expect(index.episodes.length, 2);
      expect(index.episodes[0].title, '第一話');
      expect(index.episodes[1].title, '第二話');
    });

    test('creates empty NovelIndex', () {
      final index = NovelIndex(
        title: '空の小説',
        episodes: [],
      );

      expect(index.title, '空の小説');
      expect(index.episodes, isEmpty);
    });
  });

  group('NovelSiteRegistry', () {
    test('resolves narou site from syosetu.com URL', () {
      final registry = NovelSiteRegistry();
      final url = Uri.parse('https://ncode.syosetu.com/n9669bk/');
      final site = registry.findSite(url);

      expect(site, isNotNull);
    });

    test('resolves kakuyomu site from kakuyomu.jp URL', () {
      final registry = NovelSiteRegistry();
      final url = Uri.parse('https://kakuyomu.jp/works/1177354054881162325');
      final site = registry.findSite(url);

      expect(site, isNotNull);
    });

    test('returns null for unsupported URL', () {
      final registry = NovelSiteRegistry();
      final url = Uri.parse('https://example.com/novel/123');
      final site = registry.findSite(url);

      expect(site, isNull);
    });

    test('returns null for empty host', () {
      final registry = NovelSiteRegistry();
      final url = Uri.parse('not-a-url');
      final site = registry.findSite(url);

      expect(site, isNull);
    });
  });
}
