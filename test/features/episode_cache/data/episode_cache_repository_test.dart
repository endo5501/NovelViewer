import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_repository.dart';
import 'package:novel_viewer/features/episode_cache/domain/episode_cache.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late EpisodeCacheDatabase database;
  late EpisodeCacheRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('episode_cache_repo_test_');
    database = EpisodeCacheDatabase(tempDir.path);
    repository = EpisodeCacheRepository(database);
  });

  tearDown(() async {
    await database.close();
    tempDir.deleteSync(recursive: true);
  });

  group('EpisodeCacheRepository', () {
    group('upsert', () {
      test('inserts a new episode cache entry', () async {
        final cache = EpisodeCache(
          url: 'https://ncode.syosetu.com/n9669bk/1/',
          episodeIndex: 1,
          title: 'プロローグ',
          lastModified: 'Thu, 01 Jan 2025 00:00:00 GMT',
          downloadedAt: DateTime.utc(2025, 1, 1),
        );

        await repository.upsert(cache);

        final result = await repository.findByUrl(cache.url);
        expect(result, isNotNull);
        expect(result!.url, cache.url);
        expect(result.episodeIndex, 1);
        expect(result.title, 'プロローグ');
        expect(result.lastModified, 'Thu, 01 Jan 2025 00:00:00 GMT');
      });

      test('updates existing entry on conflict', () async {
        final cache1 = EpisodeCache(
          url: 'https://ncode.syosetu.com/n9669bk/1/',
          episodeIndex: 1,
          title: 'プロローグ',
          lastModified: 'Thu, 01 Jan 2025 00:00:00 GMT',
          downloadedAt: DateTime.utc(2025, 1, 1),
        );
        await repository.upsert(cache1);

        final cache2 = EpisodeCache(
          url: 'https://ncode.syosetu.com/n9669bk/1/',
          episodeIndex: 1,
          title: 'プロローグ（改訂版）',
          lastModified: 'Fri, 01 Feb 2025 00:00:00 GMT',
          downloadedAt: DateTime.utc(2025, 2, 1),
        );
        await repository.upsert(cache2);

        final result = await repository.findByUrl(cache1.url);
        expect(result, isNotNull);
        expect(result!.title, 'プロローグ（改訂版）');
        expect(result.lastModified, 'Fri, 01 Feb 2025 00:00:00 GMT');
      });
    });

    group('findByUrl', () {
      test('returns null for non-existent URL', () async {
        final result = await repository.findByUrl('https://example.com/none');
        expect(result, isNull);
      });

      test('returns cached entry for existing URL', () async {
        final cache = EpisodeCache(
          url: 'https://ncode.syosetu.com/n9669bk/1/',
          episodeIndex: 1,
          title: 'プロローグ',
          lastModified: null,
          downloadedAt: DateTime.utc(2025, 1, 1),
        );
        await repository.upsert(cache);

        final result = await repository.findByUrl(cache.url);
        expect(result, isNotNull);
        expect(result!.lastModified, isNull);
      });
    });

    group('getAllAsMap', () {
      test('returns empty map when no entries exist', () async {
        final result = await repository.getAllAsMap();
        expect(result, isEmpty);
      });

      test('returns all entries as URL-keyed map', () async {
        final caches = [
          EpisodeCache(
            url: 'https://ncode.syosetu.com/n9669bk/1/',
            episodeIndex: 1,
            title: 'プロローグ',
            lastModified: null,
            downloadedAt: DateTime.utc(2025, 1, 1),
          ),
          EpisodeCache(
            url: 'https://ncode.syosetu.com/n9669bk/2/',
            episodeIndex: 2,
            title: '第一話',
            lastModified: 'Thu, 01 Jan 2025 00:00:00 GMT',
            downloadedAt: DateTime.utc(2025, 1, 1),
          ),
          EpisodeCache(
            url: 'https://ncode.syosetu.com/n9669bk/3/',
            episodeIndex: 3,
            title: '第二話',
            lastModified: null,
            downloadedAt: DateTime.utc(2025, 1, 1),
          ),
        ];

        for (final cache in caches) {
          await repository.upsert(cache);
        }

        final result = await repository.getAllAsMap();
        expect(result, hasLength(3));
        expect(result.containsKey('https://ncode.syosetu.com/n9669bk/1/'), isTrue);
        expect(result.containsKey('https://ncode.syosetu.com/n9669bk/2/'), isTrue);
        expect(result.containsKey('https://ncode.syosetu.com/n9669bk/3/'), isTrue);
        expect(result['https://ncode.syosetu.com/n9669bk/2/']!.title, '第一話');
      });
    });
  });
}
