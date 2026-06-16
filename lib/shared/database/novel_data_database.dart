import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'database_opener.dart';
import 'db_connection_gate.dart';

/// Per-folder `novel_data.db` — the single database file inside each novel
/// folder that holds the per-novel analysis/reading artifacts:
/// `word_summaries`, `fact_cache`, and `bookmarks`.
///
/// Unlike `episode_cache.db` / `tts_audio.db` / `tts_dictionary.db` (whose
/// contents are reproducible and may be reset on corruption), this database
/// mixes reproducible data (summaries, facts) with **non-reproducible** user
/// data (bookmarks). It therefore opens with `deleteOnFailure: false` so a
/// corrupt file surfaces to the user instead of being silently recreated —
/// the same preservation contract `NovelDatabase` applies to the global
/// metadata DB.
///
/// The novel identity is conveyed by which folder this file lives in, so none
/// of the three tables carries a `folder_name` / `novel_id` column.
class NovelDataDatabase {
  static const databaseName = 'novel_data.db';
  static const _databaseVersion = 1;
  static final _log = Logger('novel_data_db');

  final String _folderPath;
  late final DbConnectionGate<Database> _gate = DbConnectionGate<Database>(
    opener: _open,
    closer: (db) => db.close(),
  );

  NovelDataDatabase(this._folderPath);

  Future<Database> get database => _gate.resource;

  Future<Database> _open() {
    final path = p.join(_folderPath, databaseName);
    // Holds non-reproducible bookmarks → never auto-delete on open failure.
    return openOrResetDatabase(
      path: path,
      version: _databaseVersion,
      onCreate: _onCreate,
      deleteOnFailure: false,
      logger: _log,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await createCurrentSchema(db);
  }

  /// Creates the full current-version schema on [db]. Single source of truth
  /// for production `_onCreate`, for the v8→v9 migration's per-folder target,
  /// and for test fixtures — so the schema cannot drift between them.
  @visibleForTesting
  static Future<void> createCurrentSchema(Database db) async {
    await db.execute('''
      CREATE TABLE word_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
      ON word_summaries(word, covered_up_to_episode)
    ''');
    await db.execute('''
      CREATE TABLE fact_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
      ON fact_cache(word, file_name)
    ''');
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        line_number INTEGER,
        created_at TEXT NOT NULL,
        UNIQUE(file_name, line_number)
      )
    ''');
  }

  @visibleForTesting
  void setDatabase(Database db) {
    // ignore: invalid_use_of_visible_for_testing_member
    _gate.seedResource(db);
  }

  Future<void> close() => _gate.close();
}
