import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Full-chain upgrade test: seed the original v1 schema and open through
/// [NovelDatabase] so every `_onUpgrade` step (v1→2→3→4→5→6→7→8) runs in
/// sequence, exercising the historical interactions that per-step tests miss
/// (F129). The final state MUST match a fresh v8 install and preserve data.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v1 → v8 full chain reaches the v8 schema and preserves novels',
      () async {
    final tempDir = Directory.systemTemp.createTempSync('migration_full_chain_');
    try {
      final dbPath = p.join(tempDir.path, 'novel_metadata.db');

      // v1 schema: novels table only (word_summaries/bookmarks/reading_progress
      // /fact_cache are all introduced by later upgrade steps).
      final seeded = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
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
            await db.insert('novels', {
              'site_type': 'narou',
              'novel_id': 'n1234ab',
              'title': 'Seeded Novel',
              'url': 'https://ncode.syosetu.com/n1234ab/',
              'folder_name': 'narou_n1234ab',
              'episode_count': 3,
              'downloaded_at': '2026-05-01T00:00:00.000Z',
              'updated_at': null,
            });
          },
        ),
      );
      await seeded.close();

      final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
      try {
        final db = await novelDatabase.database;

        // Reaches the current version.
        final version = await db.getVersion();
        expect(version, 8, reason: 'full chain SHALL land on the current version');

        // bookmarks at v8 shape: no file_path, UNIQUE on file_name.
        final bmColumns = await db.rawQuery('PRAGMA table_info(bookmarks)');
        final bmNames = bmColumns.map((c) => c['name']).toSet();
        expect(bmNames, isNot(contains('file_path')));
        expect(bmNames, containsAll(['novel_id', 'file_name', 'line_number']));
        final bmSql = (await db.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='bookmarks'",
        )).first['sql'] as String;
        expect(bmSql.replaceAll(' ', ''),
            contains('UNIQUE(novel_id,file_name,line_number)'.replaceAll(' ', '')));

        // reading_progress at v8 shape: no file_path.
        final rpColumns =
            await db.rawQuery('PRAGMA table_info(reading_progress)');
        final rpNames = rpColumns.map((c) => c['name']).toSet();
        expect(rpNames, isNot(contains('file_path')));
        expect(rpNames, containsAll(['novel_id', 'file_name', 'updated_at']));

        // word_summaries reshaped to the v5 snapshot schema.
        final wsColumns = await db.rawQuery('PRAGMA table_info(word_summaries)');
        final wsNames = wsColumns.map((c) => c['name']).toSet();
        expect(wsNames, contains('covered_up_to_episode'));
        expect(wsNames, isNot(contains('summary_type')));

        // fact_cache exists.
        final factTables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='fact_cache'",
        );
        expect(factTables, isNotEmpty);

        // Seeded novel survived the whole chain.
        final novels = await db.query('novels');
        expect(novels.length, 1);
        expect(novels.first['folder_name'], 'narou_n1234ab');
      } finally {
        await novelDatabase.close();
      }
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}
