import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('episode_cache_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('EpisodeCacheDatabase', () {
    test('creates episode_cache.db in the specified folder', () async {
      final db = EpisodeCacheDatabase(tempDir.path);
      await db.database;

      final dbFile = File('${tempDir.path}/episode_cache.db');
      expect(dbFile.existsSync(), isTrue);

      await db.close();
    });

    test('creates episode_cache table with correct schema', () async {
      final db = EpisodeCacheDatabase(tempDir.path);
      final database = await db.database;

      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='episode_cache'",
      );
      expect(tables, hasLength(1));

      final columns = await database.rawQuery(
        "PRAGMA table_info('episode_cache')",
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames, contains('url'));
      expect(columnNames, contains('episode_index'));
      expect(columnNames, contains('title'));
      expect(columnNames, contains('last_modified'));
      expect(columnNames, contains('downloaded_at'));

      await db.close();
    });

    test('reuses existing database on subsequent opens', () async {
      final db1 = EpisodeCacheDatabase(tempDir.path);
      final database1 = await db1.database;
      await database1.insert('episode_cache', {
        'url': 'https://example.com/1',
        'episode_index': 1,
        'title': 'test',
        'last_modified': null,
        'downloaded_at': '2025-01-01T00:00:00.000Z',
      });
      await db1.close();

      final db2 = EpisodeCacheDatabase(tempDir.path);
      final database2 = await db2.database;
      final rows = await database2.query('episode_cache');
      expect(rows, hasLength(1));
      expect(rows.first['url'], 'https://example.com/1');

      await db2.close();
    });

    test('handles corrupted database by recreating', () async {
      final dbFile = File('${tempDir.path}/episode_cache.db');
      await dbFile.writeAsString('corrupted data');

      final db = EpisodeCacheDatabase(tempDir.path);
      final database = await db.database;

      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='episode_cache'",
      );
      expect(tables, hasLength(1));

      await db.close();
    });
  });
}
