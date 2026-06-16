import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('fact_cache migration v6 → v7 → v9', () {
    test('fresh install (v9) has no global fact_cache table (moved to '
        'novel_data.db)', () async {
      final tempDir =
          Directory.systemTemp.createTempSync('fact_cache_v9_fresh_');
      try {
        final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
        try {
          final db = await novelDatabase.database;

          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='fact_cache'",
          );
          expect(tables, isEmpty,
              reason: 'fact_cache now lives in each folder\'s novel_data.db, '
                  'not in the global novel_metadata.db');

          // reading_progress is retained globally.
          final rp = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='reading_progress'",
          );
          expect(rp, isNotEmpty);
        } finally {
          await novelDatabase.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('upgrade from v6 reaches v9 and drops the global per-novel tables',
        () async {
      final tempDir =
          Directory.systemTemp.createTempSync('fact_cache_v7_upgrade_');
      try {
        final dbPath = p.join(tempDir.path, 'novel_metadata.db');

        // Seed a v6-shaped database so the v6 → v7 upgrade runs in isolation.
        final seeded = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 6,
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
                CREATE TABLE reading_progress (
                  novel_id TEXT NOT NULL PRIMARY KEY,
                  file_path TEXT NOT NULL,
                  file_name TEXT NOT NULL,
                  updated_at TEXT NOT NULL
                )
              ''');
              // A real v6 DB always has a bookmarks table (added at v3). The
              // v7→v8 relative-path migration rebuilds it, so it must be present
              // in this seed for the full upgrade chain to succeed.
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
              await db.insert('word_summaries', {
                'folder_name': 'narou_n1234ab',
                'word': 'アリス',
                'covered_up_to_episode': 5,
                'summary': '要約テキスト',
                'source_file': '005_chapter5.txt',
                'created_at': '2026-05-01T02:00:00.000Z',
                'updated_at': '2026-05-01T02:00:00.000Z',
              });
            },
          ),
        );
        await seeded.close();

        final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
        try {
          final db = await novelDatabase.database;

          expect(await db.getVersion(), 9);

          // The per-novel tables are dropped at v9 (migrated into each folder's
          // novel_data.db; the data-move itself is covered by
          // novel_database_migration_v9_test). With no migrator wired here the
          // legacy rows are discarded as orphans, which is acceptable for this
          // chain-shape test.
          Future<bool> tableExists(String name) async => (await db.rawQuery(
                "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
                [name],
              )).isNotEmpty;
          expect(await tableExists('fact_cache'), isFalse);
          expect(await tableExists('word_summaries'), isFalse);
          expect(await tableExists('bookmarks'), isFalse);
          expect(await tableExists('reading_progress'), isTrue);
        } finally {
          await novelDatabase.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
