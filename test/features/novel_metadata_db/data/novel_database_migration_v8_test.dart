import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_data_migrator.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/shared/database/novel_data_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds a migrator that routes the seeded novel's rows into a real
/// `novel_data.db` under [tempPath]/narou_n1234ab, plus a helper to reopen it.
({NovelDataMigrator migrator, Directory folderDir}) _folderMigrator(
    String tempPath) {
  final folderDir = Directory(p.join(tempPath, 'narou_n1234ab'))..createSync();
  final migrator = NovelDataMigrator(
    resolveFolderPath: (f) => f == 'narou_n1234ab' ? folderDir.path : null,
    openNovelDataDb: (fp) => databaseFactoryFfi.openDatabase(
      p.join(fp, NovelDataDatabase.databaseName),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => NovelDataDatabase.createCurrentSchema(db),
      ),
    ),
  );
  return (migrator: migrator, folderDir: folderDir);
}

Future<Database> _openFolderDb(Directory folderDir) =>
    databaseFactoryFfi.openDatabase(
      p.join(folderDir.path, NovelDataDatabase.databaseName),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => NovelDataDatabase.createCurrentSchema(db),
      ),
    );

/// Seeds a v7-shaped `novel_metadata.db` at [dbPath]. The v7 schema still keeps
/// the absolute `file_path` column on both `bookmarks` and `reading_progress`,
/// which the v7 → v8 migration removes.
Future<void> _seedV7Database(
  String dbPath, {
  required Future<void> Function(Database db) seed,
}) async {
  final seeded = await databaseFactoryFfi.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 7,
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
          CREATE TABLE word_summaries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            folder_name TEXT NOT NULL,
            word TEXT NOT NULL,
            covered_up_to_episode INTEGER NOT NULL,
            summary TEXT NOT NULL,
            source_file TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE UNIQUE INDEX idx_word_summaries_unique
          ON word_summaries(folder_name, word, covered_up_to_episode)
        ''');
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            novel_id TEXT NOT NULL,
            file_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            line_number INTEGER,
            created_at TEXT NOT NULL,
            UNIQUE(novel_id, file_path, line_number)
          )
        ''');
        await db.execute('''
          CREATE TABLE reading_progress (
            novel_id TEXT NOT NULL PRIMARY KEY,
            file_path TEXT NOT NULL,
            file_name TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE fact_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            folder_name TEXT NOT NULL,
            word TEXT NOT NULL,
            file_name TEXT NOT NULL,
            facts TEXT NOT NULL,
            content_hash TEXT NOT NULL,
            prompt_version INTEGER NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE UNIQUE INDEX idx_fact_cache_unique
          ON fact_cache(folder_name, word, file_name)
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

  group('relative-path migration v7 → v8', () {
    test('fresh install (v9) has no global bookmarks table; reading_progress '
        'keeps its v8 shape', () async {
      final tempDir = Directory.systemTemp.createTempSync('relpath_v9_fresh_');
      try {
        final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
        try {
          final db = await novelDatabase.database;

          // bookmarks moved to each folder's novel_data.db → not global.
          final bm = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='bookmarks'",
          );
          expect(bm, isEmpty);

          // reading_progress: retained, no file_path column.
          final rpColumns =
              await db.rawQuery('PRAGMA table_info(reading_progress)');
          final rpNames = rpColumns.map((c) => c['name']).toSet();
          expect(rpNames, containsAll(['novel_id', 'file_name', 'updated_at']));
          expect(rpNames, isNot(contains('file_path')),
              reason: 'fresh v9 reading_progress SHALL NOT have file_path');
        } finally {
          await novelDatabase.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('v7 → v8 drops file_path then v9 migrates rows to novel_data.db',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('relpath_v8_bm_');
      try {
        final dbPath = p.join(tempDir.path, 'novel_metadata.db');
        await _seedV7Database(dbPath, seed: (db) async {
          await db.insert('bookmarks', {
            'novel_id': 'narou_n1234ab',
            'file_name': '001_chapter1.txt',
            'file_path': '/library/narou_n1234ab/001_chapter1.txt',
            'line_number': 42,
            'created_at': '2026-05-01T01:00:00.000Z',
          });
          await db.insert('bookmarks', {
            'novel_id': 'narou_n1234ab',
            'file_name': '002_chapter2.txt',
            'file_path': '/library/narou_n1234ab/002_chapter2.txt',
            'line_number': null,
            'created_at': '2026-05-01T01:05:00.000Z',
          });
        });

        final m = _folderMigrator(tempDir.path);
        final novelDatabase =
            NovelDatabase(dbDirPath: tempDir.path, dataMigrator: m.migrator);
        try {
          await novelDatabase.database;
        } finally {
          await novelDatabase.close();
        }

        final folderDb = await _openFolderDb(m.folderDir);
        try {
          final names = (await folderDb.rawQuery('PRAGMA table_info(bookmarks)'))
              .map((c) => c['name'])
              .toSet();
          expect(names, isNot(contains('file_path')));
          expect(names, isNot(contains('novel_id')));

          final rows = await folderDb.query('bookmarks', orderBy: 'file_name ASC');
          expect(rows.length, 2, reason: 'both rows preserved + migrated');
          expect(rows[0]['file_name'], '001_chapter1.txt');
          expect(rows[0]['line_number'], 42);
          expect(rows[0]['created_at'], '2026-05-01T01:00:00.000Z');
          expect(rows[1]['file_name'], '002_chapter2.txt');
          expect(rows[1]['line_number'], isNull);
        } finally {
          await folderDb.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('v7 → v8 dedup (keep earliest) survives the move to novel_data.db',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('relpath_v8_dedup_');
      try {
        final dbPath = p.join(tempDir.path, 'novel_metadata.db');
        await _seedV7Database(dbPath, seed: (db) async {
          await db.insert('bookmarks', {
            'novel_id': 'narou_n1234ab',
            'file_name': '001_chapter1.txt',
            'file_path': '/old/narou_n1234ab/001_chapter1.txt',
            'line_number': 42,
            'created_at': '2026-05-01T01:00:00.000Z',
          });
          await db.insert('bookmarks', {
            'novel_id': 'narou_n1234ab',
            'file_name': '001_chapter1.txt',
            'file_path': '/new/narou_n1234ab/001_chapter1.txt',
            'line_number': 42,
            'created_at': '2026-05-02T09:00:00.000Z',
          });
        });

        final m = _folderMigrator(tempDir.path);
        final novelDatabase =
            NovelDatabase(dbDirPath: tempDir.path, dataMigrator: m.migrator);
        try {
          await novelDatabase.database;
        } finally {
          await novelDatabase.close();
        }

        final folderDb = await _openFolderDb(m.folderDir);
        try {
          final rows = await folderDb.query('bookmarks');
          expect(rows.length, 1,
              reason: 'colliding rows SHALL be deduplicated to one');
          expect(rows.first['created_at'], '2026-05-01T01:00:00.000Z',
              reason: 'the earliest created_at SHALL be kept');
        } finally {
          await folderDb.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('v7 → v8 NULL-line dedup survives the move to novel_data.db',
        () async {
      final tempDir =
          Directory.systemTemp.createTempSync('relpath_v8_dedup_null_');
      try {
        final dbPath = p.join(tempDir.path, 'novel_metadata.db');
        await _seedV7Database(dbPath, seed: (db) async {
          await db.insert('bookmarks', {
            'novel_id': 'narou_n1234ab',
            'file_name': '001_chapter1.txt',
            'file_path': '/old/narou_n1234ab/001_chapter1.txt',
            'line_number': null,
            'created_at': '2026-05-01T01:00:00.000Z',
          });
          await db.insert('bookmarks', {
            'novel_id': 'narou_n1234ab',
            'file_name': '001_chapter1.txt',
            'file_path': '/new/narou_n1234ab/001_chapter1.txt',
            'line_number': null,
            'created_at': '2026-05-02T09:00:00.000Z',
          });
        });

        final m = _folderMigrator(tempDir.path);
        final novelDatabase =
            NovelDatabase(dbDirPath: tempDir.path, dataMigrator: m.migrator);
        try {
          await novelDatabase.database;
        } finally {
          await novelDatabase.close();
        }

        final folderDb = await _openFolderDb(m.folderDir);
        try {
          final rows = await folderDb.query('bookmarks');
          expect(rows.length, 1,
              reason: 'NULL-line collisions SHALL be deduplicated to one');
          expect(rows.first['created_at'], '2026-05-01T01:00:00.000Z');
        } finally {
          await folderDb.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('upgrade v7 → v8 drops reading_progress.file_path and preserves rows',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('relpath_v8_rp_');
      try {
        final dbPath = p.join(tempDir.path, 'novel_metadata.db');
        await _seedV7Database(dbPath, seed: (db) async {
          await db.insert('reading_progress', {
            'novel_id': 'narou_n1234ab',
            'file_path': '/library/narou_n1234ab/003_chapter3.txt',
            'file_name': '003_chapter3.txt',
            'updated_at': '2026-05-01T03:00:00.000Z',
          });
        });

        final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
        try {
          final db = await novelDatabase.database;

          final columns =
              await db.rawQuery('PRAGMA table_info(reading_progress)');
          final names = columns.map((c) => c['name']).toSet();
          expect(names, isNot(contains('file_path')),
              reason: 'v7 → v8 SHALL drop reading_progress.file_path');
          final pkColumns = columns
              .where((c) => (c['pk'] as int) > 0)
              .map((c) => c['name'])
              .toList();
          expect(pkColumns, ['novel_id']);

          final rows = await db.query('reading_progress');
          expect(rows.length, 1, reason: 'the progress row SHALL be preserved');
          expect(rows.first['novel_id'], 'narou_n1234ab');
          expect(rows.first['file_name'], '003_chapter3.txt');
          expect(rows.first['updated_at'], '2026-05-01T03:00:00.000Z');
        } finally {
          await novelDatabase.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
