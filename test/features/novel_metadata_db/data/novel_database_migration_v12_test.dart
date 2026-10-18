import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// `{objectName: normalized CREATE statement}` for every user table and index.
Future<Map<String, String>> _schemaObjects(Database db) async {
  final rows = await db.rawQuery(
    'SELECT name, sql FROM sqlite_master '
    "WHERE type IN ('table', 'index') AND name NOT LIKE 'sqlite_%' "
    "AND name NOT LIKE 'android_metadata' ORDER BY name",
  );
  return {
    for (final row in rows)
      if (row['sql'] != null)
        row['name'] as String: (row['sql'] as String)
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
  };
}

/// Seeds a `novel_metadata.db` at the v11 schema, written out by hand so the
/// test pins what a v11 file on a reader's disk actually looks like.
Future<void> _seedV11(String dbPath) async {
  final db = await databaseFactoryFfi.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 11,
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
        await db.insert('novel_reference_sources', {
          'child_folder_name': 'narou_n2',
          'parent_folder_name': 'narou_n1',
          'created_at': '2026-10-04T00:00:00.000Z',
        });
        await db.insert('novels', {
          'site_type': 'narou',
          'novel_id': 'n1',
          'title': 'Part One',
          'url': 'https://ncode.syosetu.com/n1/',
          'folder_name': 'narou_n1',
          'episode_count': 3,
          'downloaded_at': '2026-05-01T00:00:00.000Z',
        });
        await db.insert('reading_progress', {
          'novel_id': 'narou_n1',
          'file_name': '002.txt',
          'updated_at': '2026-05-02T00:00:00.000Z',
          'body_offset': 42,
          'body_hash': 'h',
        });
      },
    ),
  );
  await db.close();
}

const _syncTables = [
  'sync_remote_progress',
  'sync_own_progress',
  'sync_handled',
];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('migration_v12_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('current schema version is 12', () {
    expect(NovelDatabase.currentSchemaVersion, 12);
  });

  test('v11 → v12 adds the sync tables and keeps rows', () async {
    await _seedV11(p.join(tempDir.path, 'novel_metadata.db'));

    final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
    try {
      final db = await novelDatabase.database;
      expect(await db.getVersion(), 12);

      for (final table in _syncTables) {
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        expect(tables, hasLength(1), reason: table);
      }

      expect((await db.query('novels')).single['folder_name'], 'narou_n1');
      final progress = await db.query('reading_progress');
      expect(progress.single['body_offset'], 42);
      expect(progress.single['body_hash'], 'h');
      expect(
        (await db.query('novel_reference_sources')).single['child_folder_name'],
        'narou_n2',
      );
    } finally {
      await novelDatabase.close();
    }
  });

  test('a v11 database upgraded to v12 matches a fresh v12 schema', () async {
    final upgradedDir = Directory(p.join(tempDir.path, 'upgraded'))
      ..createSync();
    final freshDir = Directory(p.join(tempDir.path, 'fresh'))..createSync();
    await _seedV11(p.join(upgradedDir.path, 'novel_metadata.db'));

    final upgraded = NovelDatabase(dbDirPath: upgradedDir.path);
    final fresh = NovelDatabase(dbDirPath: freshDir.path);
    try {
      final upgradedSchema = await _schemaObjects(await upgraded.database);
      final freshSchema = await _schemaObjects(await fresh.database);
      for (final table in _syncTables) {
        expect(freshSchema[table], isNotNull, reason: table);
        expect(upgradedSchema[table], freshSchema[table], reason: table);
      }
      expect(
        upgradedSchema.keys.where((k) => k.contains('sync')).toSet(),
        freshSchema.keys.where((k) => k.contains('sync')).toSet(),
      );
    } finally {
      await upgraded.close();
      await fresh.close();
    }
  });

  test('the same device and novel pair cannot be stored twice', () async {
    final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
    try {
      final db = await novelDatabase.database;
      final row = {
        'device_id': 'd1',
        'novel_id': 'narou_n1',
        'device_name': 'iPad (pad)',
        'episode': 5,
        'file_name': '005.txt',
        'body_offset': 10,
        'body_hash': 'h',
        'read_at': '2026-10-18T00:00:00.000Z',
      };
      await db.insert('sync_remote_progress', row);
      await expectLater(
        db.insert('sync_remote_progress', row),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('sync_remote_progress'), hasLength(1));
    } finally {
      await novelDatabase.close();
    }
  });

  test('own progress and handled records are unique per novel', () async {
    final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
    try {
      final db = await novelDatabase.database;
      final own = {
        'novel_id': 'narou_n1',
        'episode': 5,
        'file_name': '005.txt',
        'body_offset': 10,
        'body_hash': null,
        'read_at': '2026-10-18T00:00:00.000Z',
      };
      await db.insert('sync_own_progress', own);
      await expectLater(
        db.insert('sync_own_progress', own),
        throwsA(isA<DatabaseException>()),
      );
      final handled = {
        'novel_id': 'narou_n1',
        'handled_read_at': '2026-10-18T00:00:00.000Z',
      };
      await db.insert('sync_handled', handled);
      await expectLater(
        db.insert('sync_handled', handled),
        throwsA(isA<DatabaseException>()),
      );
    } finally {
      await novelDatabase.close();
    }
  });
}
