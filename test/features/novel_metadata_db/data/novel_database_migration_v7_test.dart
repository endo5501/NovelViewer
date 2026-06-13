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

  group('fact_cache migration v6 → v7', () {
    test('fresh install at v7 has the fact_cache table with expected schema',
        () async {
      final tempDir =
          Directory.systemTemp.createTempSync('fact_cache_v7_fresh_');
      try {
        final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
        try {
          final db = await novelDatabase.database;

          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='fact_cache'",
          );
          expect(tables, isNotEmpty,
              reason: 'fact_cache table SHALL exist on fresh v7 install');

          final columns = await db.rawQuery('PRAGMA table_info(fact_cache)');
          final columnNames = columns.map((c) => c['name']).toSet();
          expect(
            columnNames,
            containsAll([
              'folder_name',
              'word',
              'file_name',
              'facts',
              'content_hash',
              'prompt_version',
              'updated_at',
            ]),
          );

          final indices = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='fact_cache'",
          );
          expect(
            indices.any((row) => row['name'] == 'idx_fact_cache_unique'),
            isTrue,
            reason: 'fact_cache SHALL have a unique index on '
                '(folder_name, word, file_name)',
          );
        } finally {
          await novelDatabase.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('upgrade from v6 to v7 preserves existing data and adds the table',
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

          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='fact_cache'",
          );
          expect(tables, isNotEmpty,
              reason: 'v6 → v7 upgrade SHALL add the fact_cache table');

          final cacheRows = await db.query('fact_cache');
          expect(cacheRows, isEmpty,
              reason: 'newly added table SHALL start empty');

          final summaryRows = await db.query('word_summaries');
          expect(summaryRows.length, 1,
              reason: 'pre-existing word_summaries SHALL be preserved');
          expect(summaryRows.first['word'], 'アリス');
        } finally {
          await novelDatabase.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
