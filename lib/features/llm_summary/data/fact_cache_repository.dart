import 'package:sqflite/sqflite.dart';
import 'package:novel_viewer/features/llm_summary/domain/fact_cache_entry.dart';

export 'package:novel_viewer/features/llm_summary/domain/fact_cache_entry.dart';

/// SQLite-backed access to the `fact_cache` table. Rows are keyed by
/// `(folder_name, word, file_name)` and store the Stage-1 facts extracted for
/// that source file, together with the `content_hash` and `prompt_version`
/// used to decide whether the cached facts are still valid on a later analysis.
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

  /// Upserts the cached facts for `(folderName, word, fileName)`. A colliding
  /// key replaces the row in place via SQLite's native upsert.
  Future<void> upsert({
    required String folderName,
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
        (folder_name, word, file_name, facts, content_hash, prompt_version,
         updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(folder_name, word, file_name) DO UPDATE SET
        facts = excluded.facts,
        content_hash = excluded.content_hash,
        prompt_version = excluded.prompt_version,
        updated_at = excluded.updated_at
      ''',
      [folderName, word, fileName, facts, contentHash, promptVersion, now],
    );
  }

  /// Returns the cache row for `(folderName, word, fileName)`, or `null`.
  Future<FactCacheEntry?> find({
    required String folderName,
    required String word,
    required String fileName,
  }) async {
    final results = await _db.query(
      'fact_cache',
      where: 'folder_name = ? AND word = ? AND file_name = ?',
      whereArgs: [folderName, word, fileName],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return FactCacheEntry.fromMap(results.first);
  }

  /// Returns every cache row for `(folderName, word)`.
  Future<List<FactCacheEntry>> findForWord({
    required String folderName,
    required String word,
  }) async {
    final results = await _db.query(
      'fact_cache',
      where: 'folder_name = ? AND word = ?',
      whereArgs: [folderName, word],
    );
    return results.map(FactCacheEntry.fromMap).toList();
  }

  /// Forces a cache miss for every file of `(folderName, word)` by writing the
  /// sentinel `content_hash`. The facts text is left intact; only validity is
  /// revoked, so the next analysis re-extracts and overwrites the rows.
  Future<void> invalidateWord({
    required String folderName,
    required String word,
  }) async {
    await _db.update(
      'fact_cache',
      {
        'content_hash': sentinelHash,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'folder_name = ? AND word = ?',
      whereArgs: [folderName, word],
    );
  }

  /// Cascade helper: removes the cache rows for `(folderName, word)`. Call
  /// alongside `LlmSummaryRepository.deleteAllForWord`.
  Future<void> deleteAllForWord({
    required String folderName,
    required String word,
  }) async {
    await _db.delete(
      'fact_cache',
      where: 'folder_name = ? AND word = ?',
      whereArgs: [folderName, word],
    );
  }

  /// Cascade helper: removes every cache row for the folder. Call alongside
  /// `LlmSummaryRepository.deleteByFolderName`.
  Future<void> deleteByFolderName(String folderName,
      {DatabaseExecutor? txn}) async {
    await (txn ?? _db).delete(
      'fact_cache',
      where: 'folder_name = ?',
      whereArgs: [folderName],
    );
  }
}
