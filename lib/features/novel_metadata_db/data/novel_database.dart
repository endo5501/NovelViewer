import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

import '../../../shared/database/database_opener.dart';

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
  /// `<libraryRoot>/<folder>` and returns their base names.
  factory NovelDatabaseSnapshotResolver.fromLibraryRoot(String libraryRoot) {
    return NovelDatabaseSnapshotResolver(folderFileLister: (folderName) {
      try {
        final dir = Directory(p.join(libraryRoot, folderName));
        if (!dir.existsSync()) return const [];
        final files = dir
            .listSync(followLinks: false)
            .whereType<File>()
            .map((f) => p.basename(f.path))
            .where((name) => name.toLowerCase().endsWith('.txt'))
            .toList()
          ..sort();
        return files;
      } catch (e, st) {
        Logger('novel_metadata_db').warning(
            'Failed to list folder $folderName during v5 migration', e, st);
        return const [];
      }
    });
  }
}

class NovelDatabase {
  static const _databaseName = 'novel_metadata.db';
  static const _databaseVersion = 7;
  static final _log = Logger('novel_metadata_db');

  final String? _dbDirPath;
  final NovelDatabaseSnapshotResolver _snapshotResolver;
  Database? _database;

  NovelDatabase({
    String? dbDirPath,
    NovelDatabaseSnapshotResolver? snapshotResolver,
  })  : _dbDirPath = dbDirPath,
        _snapshotResolver =
            snapshotResolver ?? NovelDatabaseSnapshotResolver.empty;

  Future<Database> get database async {
    final db = _database;
    if (db != null) return db;
    return _database = await _open();
  }

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
    await _createV5WordSummariesTable(db);
    await _createBookmarksTable(db);
    await _createReadingProgressTable(db);
    await _createFactCacheTable(db);
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
    final prefix = sourceFile != null ? _extractNumericPrefix(sourceFile) : null;

    if (summaryType == 'no_spoiler') {
      if (prefix != null) return prefix;
      if (sourceFile != null) {
        final rank = _lexicalRank(filesIn(folder), sourceFile);
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
      final rank = _lexicalRank(filesIn(folder), sourceFile);
      if (rank != null) return rank > base ? rank : base;
    }
    return base;
  }

  static int? _extractNumericPrefix(String fileName) {
    final match = RegExp(r'^(\d+)').firstMatch(fileName);
    return match != null ? int.parse(match.group(1)!) : null;
  }

  static int? _lexicalRank(List<String> sortedFiles, String target) {
    if (sortedFiles.isEmpty) return null;
    final index = sortedFiles.indexOf(target);
    if (index < 0) return null;
    return index + 1; // 1-origin
  }

  @visibleForTesting
  void setDatabase(Database db) {
    _database = db;
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

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
