import 'dart:io';

import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../../../shared/database/novel_data_database.dart';

/// Resolves a registered novel `folderName` (leaf) to its absolute folder path
/// on disk, or `null` when the folder no longer exists (so its rows are treated
/// as orphans and discarded during the v8→v9 migration).
typedef NovelFolderPathResolver = String? Function(String folderName);

/// Opens (creating if necessary) the `novel_data.db` for a novel folder at
/// [folderPath] and returns its [Database]. The caller owns closing it.
typedef NovelDataDbOpener = Future<Database> Function(String folderPath);

/// Injected I/O dependency for the v8→v9 migration that moves `word_summaries`,
/// `fact_cache`, and `bookmarks` from the global `novel_metadata.db` into each
/// novel's per-folder `novel_data.db`. Kept behind an interface so tests can
/// supply in-memory folder databases and a fake folder resolver instead of
/// touching the filesystem.
class NovelDataMigrator {
  final NovelFolderPathResolver resolveFolderPath;
  final NovelDataDbOpener openNovelDataDb;

  const NovelDataMigrator({
    required this.resolveFolderPath,
    required this.openNovelDataDb,
  });

  /// Default migrator used when no library root is wired (e.g. test fixtures
  /// that open a fresh schema). It resolves every folder to `null`, so a
  /// migration run discards all rows as orphans. Production MUST use
  /// [NovelDataMigrator.fromLibraryRoot].
  static NovelDataMigrator get empty => NovelDataMigrator(
        resolveFolderPath: (_) => null,
        openNovelDataDb: (_) async =>
            throw StateError('empty migrator cannot open a folder db'),
      );

  /// Production migrator: locates each registered novel folder by walking
  /// [libraryRoot] for a directory whose leaf name matches the `folderName`
  /// (so nested novels under organizational folders resolve correctly), and
  /// opens that folder's `novel_data.db` through the production schema.
  factory NovelDataMigrator.fromLibraryRoot(String libraryRoot,
      {Logger? logger}) {
    return NovelDataMigrator(
      resolveFolderPath: (folderName) {
        final root = Directory(libraryRoot);
        if (!root.existsSync()) return null;
        // Only the leaf folder_name is stored, so resolve by collecting every
        // directory under the library with that leaf name. Return it ONLY when
        // the match is unique. If two directories share the name (a registered
        // novel plus an unrelated same-named folder), we cannot tell which is
        // the novel from the name alone — returning either risks writing the
        // novel's data into the WRONG folder, so we skip it (treated as an
        // orphan: rows discarded + logged) rather than mis-target. Crashing the
        // upgrade is not an option here — it would brick startup.
        final matches = <String>[
          for (final entity in root.listSync(recursive: true, followLinks: false))
            if (entity is Directory && p.basename(entity.path) == folderName)
              entity.path,
        ];
        if (matches.length == 1) return matches.single;
        if (matches.length > 1) {
          logger?.warning(
            'v9 migration: folder name "$folderName" matches ${matches.length} '
            'directories ($matches); cannot disambiguate from the leaf name '
            'alone, skipping to avoid writing to the wrong folder',
          );
        }
        return null;
      },
      openNovelDataDb: (folderPath) async {
        final path = p.join(folderPath, NovelDataDatabase.databaseName);
        return openDatabase(
          path,
          version: 1,
          onCreate: (db, _) => NovelDataDatabase.createCurrentSchema(db),
        );
      },
    );
  }
}

/// Migrates the per-novel tables out of the global [db] (`novel_metadata.db`)
/// into each novel's `novel_data.db`, then drops the global tables. Runs inside
/// the v8→v9 `onUpgrade` transaction (see [NovelDatabase]).
///
/// Contract:
/// - Rows are grouped by their owning folder (`word_summaries.folder_name`,
///   `fact_cache.folder_name`, `bookmarks.novel_id`) and copied (dropping that
///   identity column) into the folder's `novel_data.db` via INSERT-OR-IGNORE so
///   a re-run after an interrupted migration cannot duplicate rows.
/// - Rows whose folder cannot be located on disk are discarded (orphans); the
///   discarded count is logged at WARNING level.
/// - After all extant folders are copied, the three global tables are dropped.
/// - `reading_progress` is never touched.
Future<void> migrateV8ToV9(
  Database db,
  NovelDataMigrator migrator, {
  Logger? logger,
}) async {
  final wordRows = await db.query('word_summaries');
  final factRows = await db.query('fact_cache');
  final bookmarkRows = await db.query('bookmarks');

  // folderName -> {table -> rows}
  final folders = <String>{
    ...wordRows.map((r) => r['folder_name'] as String),
    ...factRows.map((r) => r['folder_name'] as String),
    ...bookmarkRows.map((r) => r['novel_id'] as String),
  };

  var orphanedFolders = 0;
  for (final folder in folders) {
    final folderPath = migrator.resolveFolderPath(folder);
    if (folderPath == null) {
      orphanedFolders++;
      continue;
    }
    final folderDb = await migrator.openNovelDataDb(folderPath);
    try {
      // The folder's novel_data.db only ever holds migration output (the app never
      // wrote to it before v9). Clear any rows from an interrupted prior run, then
      // copy the authoritative global rows — idempotent by construction, incl.
      // whole-file bookmarks (line_number IS NULL) that UNIQUE cannot dedup.
      final batch = folderDb.batch();
      batch.delete('word_summaries');
      batch.delete('fact_cache');
      batch.delete('bookmarks');
      for (final r in wordRows.where((r) => r['folder_name'] == folder)) {
        batch.insert(
          'word_summaries',
          {
            'word': r['word'],
            'covered_up_to_episode': r['covered_up_to_episode'],
            'summary': r['summary'],
            'source_file': r['source_file'],
            'created_at': r['created_at'],
            'updated_at': r['updated_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final r in factRows.where((r) => r['folder_name'] == folder)) {
        batch.insert(
          'fact_cache',
          {
            'word': r['word'],
            'file_name': r['file_name'],
            'facts': r['facts'],
            'content_hash': r['content_hash'],
            'prompt_version': r['prompt_version'],
            'updated_at': r['updated_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final r in bookmarkRows.where((r) => r['novel_id'] == folder)) {
        batch.insert(
          'bookmarks',
          {
            'file_name': r['file_name'],
            'line_number': r['line_number'],
            'created_at': r['created_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    } finally {
      await folderDb.close();
    }
  }

  if (orphanedFolders > 0) {
    logger?.warning(
      'v9 migration: discarded per-novel rows for $orphanedFolders folder(s) '
      'no longer present on disk',
    );
  }

  // All extant folders copied — drop the global per-novel tables.
  await db.execute('DROP TABLE IF EXISTS word_summaries');
  await db.execute('DROP TABLE IF EXISTS fact_cache');
  await db.execute('DROP TABLE IF EXISTS bookmarks');
}
