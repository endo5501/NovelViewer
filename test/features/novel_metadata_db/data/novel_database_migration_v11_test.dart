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

/// Seeds a `novel_metadata.db` at the v10 schema, written out by hand so the
/// test pins what a v10 file on a reader's disk actually looks like.
Future<void> _seedV10(String dbPath) async {
  final db = await databaseFactoryFfi.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 10,
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('migration_v11_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('v10 → v11 adds the reference-source table and keeps rows', () async {
    await _seedV10(p.join(tempDir.path, 'novel_metadata.db'));

    final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
    try {
      final db = await novelDatabase.database;
      // The upgrade carries on to the current version; this test pins only
      // what v11 added.
      expect(await db.getVersion(), NovelDatabase.currentSchemaVersion);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='novel_reference_sources'",
      );
      expect(tables, hasLength(1));

      final novels = await db.query('novels');
      expect(novels.single['folder_name'], 'narou_n1');
      final progress = await db.query('reading_progress');
      expect(progress.single['body_offset'], 42);
    } finally {
      await novelDatabase.close();
    }
  });

  test('a v10 database upgraded to v11 matches a fresh v11 schema', () async {
    final upgradedDir = Directory(p.join(tempDir.path, 'upgraded'))
      ..createSync();
    final freshDir = Directory(p.join(tempDir.path, 'fresh'))..createSync();
    await _seedV10(p.join(upgradedDir.path, 'novel_metadata.db'));

    final upgraded = NovelDatabase(dbDirPath: upgradedDir.path);
    final fresh = NovelDatabase(dbDirPath: freshDir.path);
    try {
      final upgradedSchema = await _schemaObjects(await upgraded.database);
      final freshSchema = await _schemaObjects(await fresh.database);
      expect(
        upgradedSchema['novel_reference_sources'],
        freshSchema['novel_reference_sources'],
      );
      expect(
        upgradedSchema.keys.where((k) => k.contains('reference')).toSet(),
        freshSchema.keys.where((k) => k.contains('reference')).toSet(),
      );
      expect(freshSchema['novel_reference_sources'], isNotNull);
    } finally {
      await upgraded.close();
      await fresh.close();
    }
  });

  test('the same child/parent pair cannot be stored twice', () async {
    final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
    try {
      final db = await novelDatabase.database;
      final row = {
        'child_folder_name': 'narou_n2',
        'parent_folder_name': 'narou_n1',
        'created_at': '2026-10-04T00:00:00.000Z',
      };
      await db.insert('novel_reference_sources', row);
      await expectLater(
        db.insert('novel_reference_sources', row),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('novel_reference_sources'), hasLength(1));
    } finally {
      await novelDatabase.close();
    }
  });
}
