import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

import '../../../shared/database/database_opener.dart';
import '../../../shared/database/db_connection_gate.dart';
import '../../../shared/episode/episode_resolver.dart' as episode;
import 'novel_data_migrator.dart';

/// Returns the list of source-text file names for `folderName`, sorted
/// lexically. Used by the v4 → v5 migration to compute lexical-rank fallback
/// for legacy `no_spoiler` rows whose `source_file` lacks a numeric prefix.
typedef FolderFileLister = List<String> Function(String folderName);

/// Bundles I/O dependencies needed by the v4 → v5 snapshot migration so the
/// migration itself stays decoupled from `dart:io`. Tests pass a stub
/// `folderFileLister`; production wires it to a real directory scanner.
class NovelDatabaseSnapshotResolver {
  final FolderFileLister folderFileLister;

  const NovelDatabaseSnapshotResolver({required this.folderFileLister});

  /// Default resolver: returns an empty file list for every folder. The
  /// migration then falls back to `coveredUpToEpisode = 1` for rows that
  /// would otherwise need lexical rank, which is safe but loses precision.
  /// Production callers SHOULD supply a real resolver whenever the library
  /// path is known at startup.
  static NovelDatabaseSnapshotResolver get empty =>
      NovelDatabaseSnapshotResolver(folderFileLister: (_) => const []);

  /// Production resolver: lexically-sorts the `.txt` files directly inside
  /// `<libraryRoot>/<folder>` and returns their base names, via the shared
  /// [episode.listSortedTextFileNames] (single source of truth for the folder
  /// listing). Returns an empty list when the folder is missing or unreadable,
  /// logging a warning on listing failures so v5 migration precision loss stays
  /// diagnosable.
  factory NovelDatabaseSnapshotResolver.fromLibraryRoot(String libraryRoot) {
    return NovelDatabaseSnapshotResolver(
      folderFileLister: (folderName) => episode.listSortedTextFileNames(
        p.join(libraryRoot, folderName),
        onError: (e, st) => Logger('novel_metadata_db').warning(
            'Failed to list folder $folderName during v5 migration', e, st),
      ),
    );
  }
}

class NovelDatabase {
  static const _databaseName = 'novel_metadata.db';
  static const _databaseVersion = 9;

  /// The current `novel_metadata.db` schema version. Exposed so test fixtures
  /// open in-memory databases at the same version the production schema targets.
  static const int currentSchemaVersion = _databaseVersion;
  static final _log = Logger('novel_metadata_db');

  final String? _dbDirPath;
  final NovelDatabaseSnapshotResolver _snapshotResolver;
  final NovelDataMigrator _dataMigrator;
  late final DbConnectionGate<Database> _gate = DbConnectionGate<Database>(
    opener: _open,
    closer: (db) => db.close(),
  );

  NovelDatabase({
    String? dbDirPath,
    NovelDatabaseSnapshotResolver? snapshotResolver,
    NovelDataMigrator? dataMigrator,
  })  : _dbDirPath = dbDirPath,
        _snapshotResolver =
            snapshotResolver ?? NovelDatabaseSnapshotResolver.empty,
        _dataMigrator = dataMigrator ?? NovelDataMigrator.empty;

  Future<Database> get database => _gate.resource;

  Future<Database> _open() async {
    final dbPath = await _resolveDatabaseDirPath();
    final path = p.join(dbPath, _databaseName);
    // Bookmarks/library state are non-reproducible — open failure must surface, not auto-delete.
    return openOrResetDatabase(
      path: path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      deleteOnFailure: false,
      logger: _log,
    );
  }

  Future<String> _resolveDatabaseDirPath() async {
    final dirPath = _dbDirPath;
    if (dirPath != null) return dirPath;
    if (Platform.isWindows) return p.dirname(Platform.resolvedExecutable);
    return getDatabasesPath();
  }

  Future<void> _onCreate(Database db, int version) async {
    await createCurrentSchema(db);
  }

  /// Creates the full current-version schema on [db]. This is the single source
  /// of truth for the production `_onCreate` and for test fixtures: tests build
  /// their database through this method (see `test/helpers/`) so a production
  /// schema change cannot silently drift away from hand-written test DDL (F130).
  @visibleForTesting
  static Future<void> createCurrentSchema(Database db) async {
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
    // v9: the per-novel tables (word_summaries / fact_cache / bookmarks) now
    // live in each novel's per-folder `novel_data.db`. A fresh install creates
    // only the global catalog (`novels`) and `reading_progress` (kept global
    // for the cross-novel "how far read" view).
    await _createReadingProgressTableV8(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createLegacyV2WordSummariesTable(db);
    }
    if (oldVersion < 3) {
      await _createBookmarksTable(db);
    }
    if (oldVersion >= 3 && oldVersion < 4) {
      await _migrateBookmarksAddLineNumber(db);
    }
    if (oldVersion < 5) {
      await _migrateWordSummariesToSnapshots(
        db,
        resolver: _snapshotResolver,
        logger: _log,
      );
    }
    if (oldVersion < 6) {
      await _createReadingProgressTable(db);
    }
    if (oldVersion < 7) {
      await _createFactCacheTable(db);
    }
    if (oldVersion < 8) {
      await _migrateBookmarksAndProgressToRelativePath(db, logger: _log);
    }
    if (oldVersion < 9) {
      // Move word_summaries / fact_cache / bookmarks into each novel's
      // per-folder novel_data.db, then drop them here. `user_version` only
      // commits to 9 if this whole onUpgrade transaction succeeds, so an
      // interruption rolls back to 8 and the next launch re-runs the copy
      // (idempotent via INSERT OR IGNORE).
      await migrateV8ToV9(db, _dataMigrator, logger: _log);
    }
  }

  static Future<void> _createV5WordSummariesTable(Database db) async {
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
  }

  /// Schema used by v2/v3/v4. Retained here so an upgrade path from v1 still
  /// works: v1 → v2 creates the legacy table, then v4 → v5 reshapes it into
  /// snapshot form. Fresh installs skip this entirely and go straight to v5.
  static Future<void> _createLegacyV2WordSummariesTable(Database db) async {
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
    await db.execute('''
      CREATE UNIQUE INDEX idx_word_summaries_unique
      ON word_summaries(folder_name, word, summary_type)
    ''');
  }

  static Future<void> _createBookmarksTable(Database db) async {
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
  }

  /// Per-`(folder, word, file)` cache of Stage-1 fact extraction results so a
  /// re-analysis only re-extracts episodes that are new or whose source
  /// content changed. `IF NOT EXISTS` keeps the v6 → v7 upgrade idempotent if
  /// it is interrupted between the CREATE and the `user_version` bump.
  static Future<void> _createFactCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fact_cache (
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
      CREATE UNIQUE INDEX IF NOT EXISTS idx_fact_cache_unique
      ON fact_cache(folder_name, word, file_name)
    ''');
  }

  static Future<void> _createReadingProgressTable(Database db) async {
    // IF NOT EXISTS so a v5 -> v6 upgrade that was interrupted between the
    // CREATE TABLE and user_version bump can be safely retried on next launch.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reading_progress (
        novel_id TEXT NOT NULL PRIMARY KEY,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _migrateBookmarksAddLineNumber(Database db) async {
    await db.execute('ALTER TABLE bookmarks RENAME TO bookmarks_old');
    await _createBookmarksTable(db);
    await db.execute('''
      INSERT INTO bookmarks (id, novel_id, file_name, file_path, line_number, created_at)
      SELECT id, novel_id, file_name, file_path, NULL, created_at FROM bookmarks_old
    ''');
    await db.execute('DROP TABLE bookmarks_old');
  }

  /// v8 `bookmarks` schema: file identity is the move/rename-safe pair
  /// `(novel_id, file_name)` plus optional `line_number`. The absolute
  /// `file_path` column is gone — consumers reconstruct the path from the
  /// novel's current folder at read time.
  static Future<void> _createBookmarksTableV8(Database db) async {
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        novel_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        line_number INTEGER,
        created_at TEXT NOT NULL,
        UNIQUE(novel_id, file_name, line_number)
      )
    ''');
  }

  /// v8 `reading_progress` schema: stores `file_name` only (no absolute path).
  static Future<void> _createReadingProgressTableV8(Database db) async {
    await db.execute('''
      CREATE TABLE reading_progress (
        novel_id TEXT NOT NULL PRIMARY KEY,
        file_name TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// v7 → v8: drop the absolute `file_path` column from `bookmarks` and
  /// `reading_progress`, re-keying bookmark identity on
  /// `(novel_id, file_name, line_number)`.
  ///
  /// SQLite cannot drop a column or change a UNIQUE constraint in place on old
  /// engine versions, so both tables are rebuilt via the
  /// rename-old → create-canonical → copy → drop-old pattern (the same shape as
  /// the v3 → v4 [_migrateBookmarksAddLineNumber] migration). Reusing the
  /// `_create*TableV8` helpers keeps the upgraded schema identical to a fresh
  /// install — there is no second copy of the DDL to drift. sqflite runs the
  /// whole upgrade callback inside a transaction, so a mid-migration crash
  /// rolls back atomically and re-runs on the next launch (`user_version` is
  /// only bumped after success).
  ///
  /// Both tables are guaranteed to exist by this point on every real upgrade
  /// path: `bookmarks` was created at v3, `reading_progress` at v6, both before
  /// this v7 → v8 step in [_onUpgrade].
  ///
  /// Bookmark dedup: collapsing `file_path` can make formerly-distinct rows
  /// collide on the new identity `(novel_id, file_name, line_number)`. For each
  /// such group the copy keeps only the earliest row (`created_at ASC, id ASC`)
  /// — the user's first bookmark. The dedup treats `line_number IS NULL` rows
  /// for the same file as one group (NULL == NULL), matching the repository's
  /// runtime add-dedup which also special-cases NULL; the new UNIQUE constraint
  /// alone would not catch that, since SQLite treats NULLs as distinct in
  /// UNIQUE. `changes()` after the copy reports how many rows survived, so the
  /// dropped count is exact without a second table scan.
  static Future<void> _migrateBookmarksAndProgressToRelativePath(
    Database db, {
    Logger? logger,
  }) async {
    // --- bookmarks ---
    final bookmarkCountBefore =
        (await db.rawQuery('SELECT COUNT(*) AS c FROM bookmarks'))
            .first['c'] as int;
    await db.execute('ALTER TABLE bookmarks RENAME TO bookmarks_v7old');
    await _createBookmarksTableV8(db);
    // Keep, per (novel_id, file_name, line_number) group, only the earliest
    // row. The line_number match treats NULL as equal so duplicate whole-file
    // bookmarks (which the UNIQUE constraint would NOT dedup) collapse too.
    await db.execute('''
      INSERT INTO bookmarks
        (id, novel_id, file_name, line_number, created_at)
      SELECT id, novel_id, file_name, line_number, created_at
      FROM bookmarks_v7old b
      WHERE id = (
        SELECT id FROM bookmarks_v7old g
        WHERE g.novel_id = b.novel_id
          AND g.file_name = b.file_name
          AND (g.line_number = b.line_number
               OR (g.line_number IS NULL AND b.line_number IS NULL))
        ORDER BY created_at ASC, id ASC
        LIMIT 1
      )
    ''');
    final bookmarkCountAfter =
        (await db.rawQuery('SELECT changes() AS c')).first['c'] as int;
    await db.execute('DROP TABLE bookmarks_v7old');
    final deduped = bookmarkCountBefore - bookmarkCountAfter;
    if (deduped > 0) {
      logger?.warning(
        'v8 migration: deduplicated $deduped bookmark row(s) that collided on '
        '(novel_id, file_name, line_number) after dropping file_path',
      );
    }

    // --- reading_progress ---
    await db.execute(
        'ALTER TABLE reading_progress RENAME TO reading_progress_v7old');
    await _createReadingProgressTableV8(db);
    await db.execute('''
      INSERT INTO reading_progress (novel_id, file_name, updated_at)
      SELECT novel_id, file_name, updated_at FROM reading_progress_v7old
    ''');
    await db.execute('DROP TABLE reading_progress_v7old');
  }

  /// Reshape the v4 `word_summaries` table into the v5 snapshot schema.
  ///
  /// Steps:
  /// 1. Create `word_summaries_v5` with the new column set.
  /// 2. Read every v4 row, look up `novels.episode_count` per folder, and
  ///    compute `coveredUpToEpisode` per the rules documented in spec
  ///    `llm-summary-cache` Requirement "Database schema migration v4 → v5".
  /// 3. Deduplicate rows whose computed PK collides; keep the latest
  ///    `updated_at`.
  /// 4. INSERT into v5 table, DROP the old table, RENAME the new one.
  ///
  /// The unique index is created on the renamed table after the rename so we
  /// don't have two indices with the same name during the swap.
  static Future<void> _migrateWordSummariesToSnapshots(
    Database db, {
    required NovelDatabaseSnapshotResolver resolver,
    Logger? logger,
  }) async {
    // 0. Drop the old v4 unique index so we can reuse the canonical index
    //    name on the v5 table immediately. The v4 table itself stays; we
    //    still need to SELECT from it in step 2.
    await db.execute('DROP INDEX IF EXISTS idx_word_summaries_unique');

    // 1. New table + canonical unique index up-front. Any (folder, word,
    //    episode) collision in step 4's bulk INSERT will then surface at the
    //    offending row instead of at a deferred CREATE INDEX at the end —
    //    making the offending data much easier to identify.
    //
    //    `IF NOT EXISTS` makes this step idempotent against a previous
    //    interrupted migration that already created `word_summaries_v5` but
    //    didn't reach the swap (step 5). Since `user_version` is only bumped
    //    after `_onUpgrade` returns successfully, sqflite re-runs the upgrade
    //    on the next launch — and without the IF-NOT-EXISTS guard we would
    //    crash on the re-attempt with "table already exists".
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_summaries_v5 (
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
    // A retry might also have left the index from a prior attempt.
    await db.execute('DROP INDEX IF EXISTS idx_word_summaries_unique');
    await db.execute('''
      CREATE UNIQUE INDEX idx_word_summaries_unique
      ON word_summaries_v5(folder_name, word, covered_up_to_episode)
    ''');
    // Same defense for the data rows: if a prior attempt half-inserted,
    // clear it so the dedup map is the sole source of truth.
    await db.delete('word_summaries_v5');

    // 2. Read every v4 row. Sort by updated_at ascending so the "keep latest
    //    on collision" rule is naturally satisfied by overwriting earlier
    //    inserts with later ones in step 3.
    final v4Rows = await db.query(
      'word_summaries',
      orderBy: 'updated_at ASC',
    );
    final novelRows = await db.query('novels');
    final episodeCountByFolder = <String, int>{
      for (final row in novelRows)
        (row['folder_name'] as String): (row['episode_count'] as int? ?? 0),
    };

    // Cache folder -> sorted file list so each folder is scanned at most once.
    final fileListCache = <String, List<String>>{};
    List<String> filesIn(String folder) {
      return fileListCache.putIfAbsent(folder, () => resolver.folderFileLister(folder));
    }

    // 3. Convert + deduplicate (keep latest by updated_at; with ASC ordering
    //    of the input, later inserts simply overwrite earlier ones).
    final converted = <String, Map<String, Object?>>{};
    for (final row in v4Rows) {
      final folder = row['folder_name'] as String;
      final word = row['word'] as String;
      final summaryType = row['summary_type'] as String?;
      final sourceFile = row['source_file'] as String?;
      final episodeCount = episodeCountByFolder[folder] ?? 0;

      final episode = _computeCoveredUpToEpisode(
        summaryType: summaryType,
        sourceFile: sourceFile,
        novelEpisodeCount: episodeCount,
        filesIn: filesIn,
        folder: folder,
        logger: logger,
      );

      // U+0000 separator: cannot appear in folder names or words on any sane
      // filesystem / in user-facing text, so dedup keys cannot collide via
      // string concatenation (e.g. 'novel a'+'word b' vs 'novel a word'+'b').
      final key = '$folder $word $episode';
      converted[key] = {
        'folder_name': folder,
        'word': word,
        'covered_up_to_episode': episode,
        'summary': row['summary'],
        'source_file': sourceFile,
        'created_at': row['created_at'],
        'updated_at': row['updated_at'],
      };
    }

    // 4. INSERT the deduplicated rows.
    final batch = db.batch();
    for (final values in converted.values) {
      batch.insert('word_summaries_v5', values);
    }
    await batch.commit(noResult: true);

    // 5. Swap: drop the v4 table (its unique index is already gone from
    //    step 0), then rename — the canonical unique index follows the
    //    table across ALTER TABLE RENAME without needing to be recreated.
    //    `IF EXISTS` covers the rare retry scenario where the old table
    //    was already dropped in a prior partial attempt.
    await db.execute('DROP TABLE IF EXISTS word_summaries');
    await db.execute('ALTER TABLE word_summaries_v5 RENAME TO word_summaries');
  }

  static int _computeCoveredUpToEpisode({
    required String? summaryType,
    required String? sourceFile,
    required int novelEpisodeCount,
    required List<String> Function(String folder) filesIn,
    required String folder,
    Logger? logger,
  }) {
    final prefix =
        sourceFile != null ? episode.extractNumericPrefix(sourceFile) : null;

    if (summaryType == 'no_spoiler') {
      if (prefix != null) return prefix;
      if (sourceFile != null) {
        final rank = episode.lexicalRankOf(filesIn(folder), sourceFile);
        if (rank != null) return rank;
        logger?.warning(
            'v5 migration: could not resolve lexical rank for '
            '$folder/$sourceFile; falling back to 1');
        return 1;
      }
      logger?.warning(
          'v5 migration: no_spoiler row in $folder has NULL source_file; '
          'falling back to coveredUpToEpisode=1');
      return 1;
    }

    // 'spoiler' or any unexpected legacy value: treat as full-scope intent.
    final base = novelEpisodeCount > 0 ? novelEpisodeCount : 1;
    if (prefix != null) {
      return prefix > base ? prefix : base;
    }
    if (sourceFile != null) {
      final rank = episode.lexicalRankOf(filesIn(folder), sourceFile);
      if (rank != null) return rank > base ? rank : base;
    }
    return base;
  }

  @visibleForTesting
  void setDatabase(Database db) {
    // setDatabase is itself a test-only seam; delegating to the gate's
    // test-only seed keeps the injected in-memory database behind the gate.
    // ignore: invalid_use_of_visible_for_testing_member
    _gate.seedResource(db);
  }

  /// Exposed for migration tests: runs the v4 → v5 migration against a fresh
  /// in-memory database seeded by `seedV4`, then returns the resulting v5
  /// `word_summaries` rows.
  @visibleForTesting
  static Future<List<Map<String, Object?>>> runMigrationForTesting({
    required Future<void> Function(Database db) seedV4,
    required NovelDatabaseSnapshotResolver snapshotResolver,
  }) async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 4,
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
          await _createLegacyV2WordSummariesTable(db);
          await _createBookmarksTable(db);
          await seedV4(db);
        },
      ),
    );
    try {
      await _migrateWordSummariesToSnapshots(
        db,
        resolver: snapshotResolver,
      );
      return List<Map<String, Object?>>.unmodifiable(
        await db.query('word_summaries'),
      );
    } finally {
      await db.close();
    }
  }

  /// Exposed for migration tests: applies the production v5 schema to an
  /// arbitrary database so callers can verify the index/column shape.
  @visibleForTesting
  static Future<void> createV5SchemaForTesting(Database db) async {
    await _createV5WordSummariesTable(db);
  }

  Future<void> close() => _gate.close();
}
