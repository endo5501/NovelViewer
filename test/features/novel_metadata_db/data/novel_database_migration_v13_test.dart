import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Seeds a `novel_metadata.db` at the v12 schema, written out by hand so the
/// test pins what a v12 file on a reader's disk actually looks like.
Future<void> _seedV12(String dbPath) async {
  final db = await databaseFactoryFfi.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 12,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE novels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_type TEXT NOT NULL,
            novel_id TEXT NOT NULL,
            title TEXT NOT NULL,
            url TEXT NOT NULL,
            folder_name TEXT NOT NULL UNIQUE,
            episode_count INTEGER NOT NULL DEFAULT 0,
            downloaded_at TEXT NOT NULL,
            updated_at TEXT
          )
        ''');
        await db.execute('''
          CREATE UNIQUE INDEX idx_novels_site_novel
          ON novels(site_type, novel_id)
        ''');
        await db.execute('''
          CREATE TABLE reading_progress (
            novel_id TEXT NOT NULL PRIMARY KEY,
            file_name TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'ALTER TABLE reading_progress ADD COLUMN body_offset INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE reading_progress ADD COLUMN body_hash TEXT',
        );
        await db.execute('''
          CREATE TABLE novel_reference_sources (
            child_folder_name TEXT NOT NULL,
            parent_folder_name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            PRIMARY KEY (child_folder_name, parent_folder_name)
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_novel_reference_sources_parent
          ON novel_reference_sources(parent_folder_name)
        ''');
        await db.execute('''
          CREATE TABLE sync_remote_progress (
            device_id TEXT NOT NULL,
            novel_id TEXT NOT NULL,
            device_name TEXT NOT NULL,
            episode INTEGER NOT NULL,
            file_name TEXT NOT NULL,
            body_offset INTEGER NOT NULL,
            body_hash TEXT,
            read_at TEXT NOT NULL,
            PRIMARY KEY (device_id, novel_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_own_progress (
            novel_id TEXT NOT NULL PRIMARY KEY,
            episode INTEGER NOT NULL,
            file_name TEXT NOT NULL,
            body_offset INTEGER NOT NULL,
            body_hash TEXT,
            read_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_handled (
            novel_id TEXT NOT NULL PRIMARY KEY,
            handled_read_at TEXT NOT NULL
          )
        ''');
        await db.insert('novels', {
          'site_type': 'narou',
          'novel_id': 'n1',
          'title': 'Part One',
          'url': 'https://ncode.syosetu.com/n1/',
          'folder_name': 'narou_n1',
          'episode_count': 3,
          'downloaded_at': '2026-05-01T00:00:00.000Z',
          'updated_at': '2026-05-03T00:00:00.000Z',
        });
        await db.insert('reading_progress', {
          'novel_id': 'narou_n1',
          'file_name': '002.txt',
          'updated_at': '2026-05-02T00:00:00.000Z',
          'body_offset': 42,
          'body_hash': 'h',
        });
        await db.insert('novel_reference_sources', {
          'child_folder_name': 'narou_n2',
          'parent_folder_name': 'narou_n1',
          'created_at': '2026-10-04T00:00:00.000Z',
        });
        await db.insert('sync_handled', {
          'novel_id': 'narou_n1',
          'handled_read_at': '2026-10-18T00:00:00.000Z',
        });
      },
    ),
  );
  await db.close();
}

/// `{column name: (type, notnull)}` of the `novels` table.
Future<Map<String, (String, int)>> _novelsColumns(Database db) async {
  final rows = await db.rawQuery('PRAGMA table_info(novels)');
  return {
    for (final row in rows)
      row['name'] as String: (row['type'] as String, row['notnull'] as int),
  };
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('migration_v13_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('a fresh database has the nullable update-check columns', () async {
    final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
    try {
      final columns = await _novelsColumns(await novelDatabase.database);
      expect(columns['latest_episode_count'], ('INTEGER', 0));
      expect(columns['update_checked_at'], ('TEXT', 0));
    } finally {
      await novelDatabase.close();
    }
  });

  test('v12 → v13 adds the columns as NULL and keeps every row', () async {
    await _seedV12(p.join(tempDir.path, 'novel_metadata.db'));

    final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
    try {
      final db = await novelDatabase.database;
      expect(await db.getVersion(), 13);

      final novel = (await db.query('novels')).single;
      expect(novel['folder_name'], 'narou_n1');
      expect(novel['title'], 'Part One');
      expect(novel['episode_count'], 3);
      expect(novel['downloaded_at'], '2026-05-01T00:00:00.000Z');
      expect(novel['updated_at'], '2026-05-03T00:00:00.000Z');
      expect(novel.containsKey('latest_episode_count'), isTrue);
      expect(novel['latest_episode_count'], isNull);
      expect(novel.containsKey('update_checked_at'), isTrue);
      expect(novel['update_checked_at'], isNull);

      final progress = (await db.query('reading_progress')).single;
      expect(progress['body_offset'], 42);
      expect(
        (await db.query('novel_reference_sources')).single['child_folder_name'],
        'narou_n2',
      );
      expect((await db.query('sync_handled')).single['novel_id'], 'narou_n1');
    } finally {
      await novelDatabase.close();
    }
  });

  test('a v12 database upgraded to v13 matches a fresh novels table', () async {
    final upgradedDir = Directory(p.join(tempDir.path, 'upgraded'))
      ..createSync();
    final freshDir = Directory(p.join(tempDir.path, 'fresh'))..createSync();
    await _seedV12(p.join(upgradedDir.path, 'novel_metadata.db'));

    final upgraded = NovelDatabase(dbDirPath: upgradedDir.path);
    final fresh = NovelDatabase(dbDirPath: freshDir.path);
    try {
      expect(
        await _novelsColumns(await upgraded.database),
        await _novelsColumns(await fresh.database),
      );
    } finally {
      await upgraded.close();
      await fresh.close();
    }
  });
}
