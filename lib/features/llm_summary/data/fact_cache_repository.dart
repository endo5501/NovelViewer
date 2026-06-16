import 'package:sqflite/sqflite.dart';
import 'package:novel_viewer/features/llm_summary/domain/fact_cache_entry.dart';

export 'package:novel_viewer/features/llm_summary/domain/fact_cache_entry.dart';

/// SQLite-backed access to one novel's `fact_cache` table inside its per-folder
/// `novel_data.db`. Rows are keyed by `(word, file_name)` and store the Stage-1
/// facts extracted for that source file, together with the `content_hash` and
/// `prompt_version` used to decide whether the cached facts are still valid on
/// a later analysis. The novel identity is the database the repository is bound
/// to, so no `folder_name` is passed or stored.
class FactCacheRepository {
  final Database _db;

  FactCacheRepository(this._db);

  /// The current fact-extraction prompt format version. Bump this whenever
  /// `LlmPromptBuilder.buildFactExtractionPrompt` changes shape so that facts
  /// produced by an older prompt are treated as invalid and re-extracted.
  static const int currentPromptVersion = 1;

  /// Invalid sentinel `content_hash`. A row carrying this value can never be
  /// a valid cache hit, so writing it forces the next analysis to re-extract
  /// that file (used by `invalidateWord`).
  static const String sentinelHash = '';

  /// Upserts the cached facts for `(word, fileName)`. A colliding key replaces
  /// the row in place via SQLite's native upsert.
  Future<void> upsert({
    required String word,
    required String fileName,
    required String facts,
    required String contentHash,
    required int promptVersion,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.rawInsert(
      '''
      INSERT INTO fact_cache
        (word, file_name, facts, content_hash, prompt_version, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(word, file_name) DO UPDATE SET
        facts = excluded.facts,
        content_hash = excluded.content_hash,
        prompt_version = excluded.prompt_version,
        updated_at = excluded.updated_at
      ''',
      [word, fileName, facts, contentHash, promptVersion, now],
    );
  }

  /// Returns the cache row for `(word, fileName)`, or `null`.
  Future<FactCacheEntry?> find({
    required String word,
    required String fileName,
  }) async {
    final results = await _db.query(
      'fact_cache',
      where: 'word = ? AND file_name = ?',
      whereArgs: [word, fileName],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return FactCacheEntry.fromMap(results.first);
  }

  /// Returns every cache row for `word`.
  Future<List<FactCacheEntry>> findForWord({
    required String word,
  }) async {
    final results = await _db.query(
      'fact_cache',
      where: 'word = ?',
      whereArgs: [word],
    );
    return results.map(FactCacheEntry.fromMap).toList();
  }

  /// Forces a cache miss for every file of `word` by writing the sentinel
  /// `content_hash`. The facts text is left intact; only validity is revoked,
  /// so the next analysis re-extracts and overwrites the rows.
  Future<void> invalidateWord({
    required String word,
  }) async {
    await _db.update(
      'fact_cache',
      {
        'content_hash': sentinelHash,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'word = ?',
      whereArgs: [word],
    );
  }

  /// Cascade helper: removes the cache rows for `word`. Call alongside
  /// `LlmSummaryRepository.deleteAllForWord`.
  Future<void> deleteAllForWord({
    required String word,
  }) async {
    await _db.delete(
      'fact_cache',
      where: 'word = ?',
      whereArgs: [word],
    );
  }
}
