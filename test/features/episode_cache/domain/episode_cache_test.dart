import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_cache/domain/episode_cache.dart';

void main() {
  group('EpisodeCache', () {
    test('toMap converts to database map', () {
      final cache = EpisodeCache(
        url: 'https://ncode.syosetu.com/n9669bk/1/',
        episodeIndex: 1,
        title: 'プロローグ',
        lastModified: 'Thu, 01 Jan 2025 00:00:00 GMT',
        downloadedAt: DateTime.utc(2025, 1, 1),
      );

      final map = cache.toMap();

      expect(map['url'], 'https://ncode.syosetu.com/n9669bk/1/');
      expect(map['episode_index'], 1);
      expect(map['title'], 'プロローグ');
      expect(map['last_modified'], 'Thu, 01 Jan 2025 00:00:00 GMT');
      expect(map['downloaded_at'], '2025-01-01T00:00:00.000Z');
    });

    test('fromMap creates instance from database map', () {
      final map = {
        'url': 'https://ncode.syosetu.com/n9669bk/1/',
        'episode_index': 1,
        'title': 'プロローグ',
        'last_modified': 'Thu, 01 Jan 2025 00:00:00 GMT',
        'downloaded_at': '2025-01-01T00:00:00.000Z',
      };

      final cache = EpisodeCache.fromMap(map);

      expect(cache.url, 'https://ncode.syosetu.com/n9669bk/1/');
      expect(cache.episodeIndex, 1);
      expect(cache.title, 'プロローグ');
      expect(cache.lastModified, 'Thu, 01 Jan 2025 00:00:00 GMT');
      expect(cache.downloadedAt, DateTime.utc(2025, 1, 1));
    });

    test('fromMap handles null last_modified', () {
      final map = {
        'url': 'https://ncode.syosetu.com/n9669bk/1/',
        'episode_index': 1,
        'title': 'プロローグ',
        'last_modified': null,
        'downloaded_at': '2025-01-01T00:00:00.000Z',
      };

      final cache = EpisodeCache.fromMap(map);

      expect(cache.lastModified, isNull);
    });

    test('toMap and fromMap roundtrip preserves data', () {
      final original = EpisodeCache(
        url: 'https://kakuyomu.jp/works/123/episodes/456',
        episodeIndex: 5,
        title: '第五話',
        lastModified: null,
        downloadedAt: DateTime.utc(2025, 6, 15, 12, 30),
      );

      final restored = EpisodeCache.fromMap(original.toMap());

      expect(restored.url, original.url);
      expect(restored.episodeIndex, original.episodeIndex);
      expect(restored.title, original.title);
      expect(restored.lastModified, original.lastModified);
      expect(restored.downloadedAt, original.downloadedAt);
    });
  });
}
