import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Full-chain upgrade test: seed the original v1 schema and open through
/// [NovelDatabase] so every `_onUpgrade` step (v1→2→…→9) runs in sequence,
/// exercising the historical interactions that per-step tests miss (F129). The
/// final state MUST match a fresh v9 install (per-novel tables moved into each
/// folder's novel_data.db and dropped here) and preserve `novels` /
/// `reading_progress`.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v1 → v9 full chain reaches the v9 schema and preserves novels',
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
        expect(version, 9, reason: 'full chain SHALL land on the current version');

        // v9 drops the per-novel tables (moved into each folder's
        // novel_data.db). They MUST be absent in the global schema.
        Future<bool> tableExists(String name) async => (await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
              [name],
            )).isNotEmpty;
        expect(await tableExists('word_summaries'), isFalse);
        expect(await tableExists('fact_cache'), isFalse);
        expect(await tableExists('bookmarks'), isFalse);

        // reading_progress is retained at the v8 shape: no file_path.
        final rpColumns =
            await db.rawQuery('PRAGMA table_info(reading_progress)');
        final rpNames = rpColumns.map((c) => c['name']).toSet();
        expect(rpNames, isNot(contains('file_path')));
        expect(rpNames, containsAll(['novel_id', 'file_name', 'updated_at']));

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
