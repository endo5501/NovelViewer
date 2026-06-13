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

  group('reading_progress migration v5 → v6', () {
    test('fresh install at v6 has the reading_progress table', () async {
      final tempDir =
          Directory.systemTemp.createTempSync('reading_progress_v6_fresh_');
      try {
        final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
        try {
          final db = await novelDatabase.database;

          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='reading_progress'",
          );
          expect(tables, isNotEmpty,
              reason: 'reading_progress table SHALL exist on fresh v6 install');

          final columns =
              await db.rawQuery('PRAGMA table_info(reading_progress)');
          final columnNames = columns.map((c) => c['name']).toSet();
          // Fresh install now lands at v8, which drops the absolute file_path
          // column (F128). reading_progress identifies the file by file_name.
          expect(columnNames,
              containsAll(['novel_id', 'file_name', 'updated_at']));
          expect(columnNames, isNot(contains('file_path')));

          final pkColumns = columns
              .where((c) => (c['pk'] as int) > 0)
              .map((c) => c['name'])
              .toList();
          expect(pkColumns, ['novel_id'],
              reason: 'novel_id SHALL be the PRIMARY KEY');
        } finally {
          await novelDatabase.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('upgrade from v5 to v6 preserves existing data and adds the table',
        () async {
      final tempDir =
          Directory.systemTemp.createTempSync('reading_progress_v6_upgrade_');
      try {
        final dbPath = p.join(tempDir.path, 'novel_metadata.db');

        // Seed a v5-shaped database (post llm-summary-snapshots reshape:
        // word_summaries has covered_up_to_episode, bookmarks already has
        // line_number) so the v5 → v6 upgrade is exercised in isolation.
        final seeded = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 5,
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
              await db.insert('novels', {
                'site_type': 'narou',
                'novel_id': 'n1234ab',
                'title': 'Seeded Novel',
                'url': 'https://ncode.syosetu.com/n1234ab/',
                'folder_name': 'narou_n1234ab',
                'episode_count': 5,
                'downloaded_at': '2026-05-01T00:00:00.000Z',
                'updated_at': null,
              });
              await db.insert('bookmarks', {
                'novel_id': 'narou_n1234ab',
                'file_name': '001_chapter1.txt',
                'file_path': '/library/narou_n1234ab/001_chapter1.txt',
                'line_number': 42,
                'created_at': '2026-05-01T01:00:00.000Z',
              });
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

        // Re-open through NovelDatabase, which runs the v5 → v6 upgrade
        // and creates the reading_progress table.
        final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
        try {
          final db = await novelDatabase.database;

          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='reading_progress'",
          );
          expect(tables, isNotEmpty,
              reason: 'v5 → v6 upgrade SHALL add the reading_progress table');

          final rpRows = await db.query('reading_progress');
          expect(rpRows, isEmpty,
              reason: 'newly added table SHALL start empty');

          final novelRows = await db.query('novels');
          expect(novelRows.length, 1,
              reason: 'pre-existing novels rows SHALL be preserved');
          expect(novelRows.first['folder_name'], 'narou_n1234ab');

          final bookmarkRows = await db.query('bookmarks');
          expect(bookmarkRows.length, 1,
              reason: 'pre-existing bookmarks SHALL be preserved');
          expect(bookmarkRows.first['line_number'], 42);

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
