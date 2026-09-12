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

  /// Current schema version. Public so the v8→v9 migration, which creates
  /// these files itself, stamps the same number the schema it writes actually
  /// is — a target created at an older number would carry the current tables
  /// under a stale `user_version`, which is the drift this file works to
  /// avoid.
  static const int currentVersion = 2;
  static final _log = Logger('novel_data_db');

  final String _folderPath;
  late final DbConnectionGate<Database> _gate = DbConnectionGate<Database>(
    opener: _open,
    closer: (db) => db.close(),
  );

  NovelDataDatabase(this._folderPath);

  Future<Database> get database => _gate.resource;

  Future<Database> _open() => openFile(p.join(_folderPath, databaseName));

  /// Opens the `novel_data.db` at [path] with this file's version and its
  /// three schema callbacks.
  ///
  /// The single place any code opens one of these. The v8→v9 migration creates
  /// these files itself and used to spell the same wiring out a second time,
  /// which is how it came to create the current tables stamped at an older
  /// version. One entry point is what stops that from happening again at the
  /// next schema change.
  ///
  /// Holds non-reproducible bookmarks → never auto-delete on open failure.
  static Future<Database> openFile(String path, {Logger? logger}) {
    return openOrResetDatabase(
      path: path,
      version: currentVersion,
      onCreate: (db, _) => createCurrentSchema(db),
      onUpgrade: upgradeToCurrent,
      onDowngrade: refuseDowngrade,
      deleteOnFailure: false,
      logger: logger ?? _log,
    );
  }

  /// v1 → v2: `fact_cache` gains `model_id`, and its unique key becomes
  /// `(word, file_name, model_id)`.
  ///
  /// The table is rebuilt rather than altered. Its v1 rows do not survive
  /// either way — a row with no model identity could never be found by any
  /// client (none declares an empty identity) and could never be replaced by
  /// an upsert (the key differs), so it would be residue rather than a cache
  /// entry. With nothing to preserve, `ALTER TABLE ADD COLUMN` buys nothing
  /// and costs schema drift: SQLite demands a `DEFAULT` clause to add a NOT
  /// NULL column, so an altered table's SQL would differ forever from a
  /// freshly created one. Recreating from the same definition keeps the two
  /// paths identical.
  ///
  /// What the reader pays is one round of re-extraction per word, the same
  /// price a `prompt_version` bump already charges. Their saved summaries are
  /// untouched, as are their bookmarks.
  static Future<void> upgradeToCurrent(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // The count is the only trace of why a word re-extracts after an update,
      // so record it before the rows are gone.
      final discarded =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM fact_cache'),
          ) ??
          0;
      await db.execute('DROP INDEX IF EXISTS idx_fact_cache_unique');
      await db.execute('DROP TABLE IF EXISTS fact_cache');
      await _createFactCache(db);
      if (discarded > 0) {
        _log.info(
          'novel_data.db v1→v2: discarded $discarded cached fact row(s) of '
          'unknown model provenance; the affected words re-extract on their '
          'next analysis',
        );
      }
    }
  }

  /// Creates the full current-version schema on [db]. Single source of truth
  /// for production `_onCreate`, for the v8→v9 migration's per-folder target
  /// ([NovelDataMigrator]), and for test fixtures — so the schema cannot drift
  /// between them.
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
    await _createFactCache(db);
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

  /// Refuses to open a database written by a newer schema than this build
  /// knows.
  ///
  /// Not a formality. With no downgrade callback, sqflite runs nothing and
  /// then writes the requested version anyway, leaving a file whose tables are
  /// the newer shape under an older `user_version`. A build that trusted that
  /// stamp would emit an upsert naming a unique key the table no longer
  /// carries, and fail on every fact-cache write with nothing to explain it.
  /// Failing the open says what actually happened.
  ///
  /// This cannot protect a build already in a reader's hands, which has no
  /// such callback; it keeps the next one from inheriting the same trap.
  static Future<void> refuseDowngrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    throw StateError(
      'novel_data.db is at schema version $oldVersion, newer than the '
      'version $newVersion this build understands. Refusing to open it '
      'rather than stamp it down and write rows the schema cannot hold.',
    );
  }

  /// `fact_cache` alone, so the v1 → v2 upgrade can rebuild exactly the table
  /// a fresh database gets. Keyed by `(word, file_name, model_id)`: which
  /// model extracted a fact is part of the row's identity, not a property to
  /// check afterwards, so each model keeps its own shelf and no analysis run
  /// mixes facts from two of them.
  static Future<void> _createFactCache(Database db) async {
    await db.execute('''
      CREATE TABLE fact_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        file_name TEXT NOT NULL,
        facts TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        prompt_version INTEGER NOT NULL,
        model_id TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_fact_cache_unique
      ON fact_cache(word, file_name, model_id)
    ''');
  }

  @visibleForTesting
  void setDatabase(Database db) {
    // ignore: invalid_use_of_visible_for_testing_member
    _gate.seedResource(db);
  }

  Future<void> close() => _gate.close();
}
