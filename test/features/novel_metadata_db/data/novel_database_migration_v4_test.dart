import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_data_migrator.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/shared/database/novel_data_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Seeds a complete historical v3 database (novels + v2-shape word_summaries +
/// v3-shape bookmarks without `line_number`) at [dbPath]. Production no longer
/// retains these historical shapes, so they must be hand-written here — but the
/// migration under test runs through the production `NovelDatabase` upgrade path
/// (real `_onUpgrade` ordering), not a step-skipping bypass helper (F129).
///
/// `_onUpgrade` gates each step on `oldVersion` only (not `newVersion`), so
/// opening a v3 database always runs the full v3→v8 chain. The v3→v4 bookmark
/// migration is therefore observed at the v8 endpoint: its signature is that
/// pre-v4 rows survive with `line_number` defaulted to NULL.
Future<void> _seedV3Database(
  String dbPath, {
  required Future<void> Function(Database db) seed,
}) async {
  final seeded = await databaseFactoryFfi.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 3,
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
        // v2-shape word_summaries (summary_type, not covered_up_to_episode) so
        // the v4→v5 snapshot migration has a table to reshape.
        await db.execute('''
          CREATE TABLE word_summaries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            folder_name TEXT NOT NULL,
            word TEXT NOT NULL,
            summary_type TEXT NOT NULL,
            summary TEXT NOT NULL,
            source_file TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        // Genuine v3 bookmarks: no line_number, UNIQUE(novel_id, file_path).
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            novel_id TEXT NOT NULL,
            file_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            created_at TEXT NOT NULL,
            UNIQUE(novel_id, file_path)
          )
        ''');
        await seed(db);
      },
    ),
  );
  await seeded.close();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('bookmarks migration v3 → v4 → v9', () {
    test('pre-v4 bookmarks survive the chain and migrate into novel_data.db '
        'with line_number defaulted to NULL', () async {
      final tempDir = Directory.systemTemp.createTempSync('migration_v4_bm_');
      try {
        final dbPath = p.join(tempDir.path, 'novel_metadata.db');
        await _seedV3Database(dbPath, seed: (db) async {
          // Distinct file_name so the later v7→v8 (novel_id, file_name)
          // re-keying preserves both rows rather than deduplicating them.
          await db.insert('bookmarks', {
            'novel_id': 'narou_n1234ab',
            'file_name': '001_chapter1.txt',
            'file_path': '/library/narou_n1234ab/001_chapter1.txt',
            'created_at': '2026-05-01T01:00:00.000Z',
          });
          await db.insert('bookmarks', {
            'novel_id': 'narou_n1234ab',
            'file_name': '002_chapter2.txt',
            'file_path': '/library/narou_n1234ab/002_chapter2.txt',
            'created_at': '2026-05-01T01:05:00.000Z',
          });
        });

        // The novel's folder + its novel_data.db destination for the v9 move.
        final folderDir = Directory(p.join(tempDir.path, 'narou_n1234ab'))
          ..createSync();
        final migrator = NovelDataMigrator(
          resolveFolderPath: (folder) =>
              folder == 'narou_n1234ab' ? folderDir.path : null,
          openNovelDataDb: (folderPath) => databaseFactoryFfi.openDatabase(
            p.join(folderPath, NovelDataDatabase.databaseName),
            options: OpenDatabaseOptions(
              version: 1,
              onCreate: (db, _) => NovelDataDatabase.createCurrentSchema(db),
            ),
          ),
        );

        // Open through the production upgrade path (real _onUpgrade ordering),
        // which runs v3→v4 (adds line_number) … → v9 (moves bookmarks into the
        // folder's novel_data.db and drops the global table).
        final novelDatabase =
            NovelDatabase(dbDirPath: tempDir.path, dataMigrator: migrator);
        try {
          final db = await novelDatabase.database;
          expect(await db.getVersion(), 9);

          // The global bookmarks table is dropped at v9.
          final globalBm = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='bookmarks'",
          );
          expect(globalBm, isEmpty);
        } finally {
          await novelDatabase.close();
        }

        // Both pre-v4 bookmark rows survived the full chain and were migrated
        // into the folder's novel_data.db — each with the NULL line_number that
        // the v3→v4 step defaulted, and no novel_id column.
        final folderDb = await databaseFactoryFfi.openDatabase(
          p.join(folderDir.path, NovelDataDatabase.databaseName),
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) => NovelDataDatabase.createCurrentSchema(db),
          ),
        );
        try {
          final columns = await folderDb.rawQuery('PRAGMA table_info(bookmarks)');
          final names = columns.map((c) => c['name']).toSet();
          expect(names, contains('line_number'));
          expect(names, isNot(contains('novel_id')));

          final rows =
              await folderDb.query('bookmarks', orderBy: 'file_name ASC');
          expect(rows.length, 2,
              reason: 'pre-v4 bookmark rows SHALL be preserved + migrated');
          expect(rows[0]['file_name'], '001_chapter1.txt');
          expect(rows[0]['created_at'], '2026-05-01T01:00:00.000Z');
          expect(rows[0]['line_number'], isNull);
          expect(rows[1]['file_name'], '002_chapter2.txt');
          expect(rows[1]['line_number'], isNull);
        } finally {
          await folderDb.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
