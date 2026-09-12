import 'package:sqflite/sqflite.dart';
import 'package:novel_viewer/features/llm_summary/domain/fact_cache_entry.dart';

export 'package:novel_viewer/features/llm_summary/domain/fact_cache_entry.dart';

/// SQLite-backed access to one novel's `fact_cache` table inside its per-folder
/// `novel_data.db`. Rows are keyed by `(word, file_name, model_id)` and store
/// the Stage-1 facts extracted for that source file, together with the
/// `content_hash` and `prompt_version` used to decide whether the cached facts
/// are still valid on a later analysis. The novel identity is the database the
/// repository is bound to, so no `folder_name` is passed or stored.
///
/// The model is part of the key, so each model has its own shelf. A row written
/// by another model is not a stale entry for this one to refresh: it is not
/// this one's row at all, and [find] does not return it. That is what keeps a
/// single analysis run from assembling facts a small on-device model wrote
/// alongside facts a large server model wrote, which the reader would have no
/// way to tell apart in the summary that results.
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

  /// Upserts the cached facts for `(word, fileName, modelId)`. A colliding key
  /// replaces the row in place via SQLite's native upsert; the same file under
  /// a different model is a different key and so a separate row.
  Future<void> upsert({
    required String word,
    required String fileName,
    required String facts,
    required String contentHash,
    required int promptVersion,
    required String modelId,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.rawInsert(
      '''
      INSERT INTO fact_cache
        (word, file_name, facts, content_hash, prompt_version,
         model_id, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(word, file_name, model_id) DO UPDATE SET
        facts = excluded.facts,
        content_hash = excluded.content_hash,
        prompt_version = excluded.prompt_version,
        updated_at = excluded.updated_at
      ''',
      [word, fileName, facts, contentHash, promptVersion, modelId, now],
    );
  }

  /// Returns the cache row for `(word, fileName, modelId)`, or `null`.
  ///
  /// A row another model wrote for the same file is not returned and is not
  /// reported as anything: it is simply not this model's row.
  Future<FactCacheEntry?> find({
    required String word,
    required String fileName,
    required String modelId,
  }) async {
    final results = await _db.query(
      'fact_cache',
      where: 'word = ? AND file_name = ? AND model_id = ?',
      whereArgs: [word, fileName, modelId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return FactCacheEntry.fromMap(results.first);
  }

  /// Returns every cache row for `word`, under every model. The read-only
  /// detail inspector wants all of them; an analysis run never does.
  Future<List<FactCacheEntry>> findForWord({required String word}) async {
    final results = await _db.query(
      'fact_cache',
      where: 'word = ?',
      whereArgs: [word],
    );
    return results.map(FactCacheEntry.fromMap).toList();
  }

  /// Forces a cache miss for the files of `word` under [modelId] by writing the
  /// sentinel `content_hash`. The facts text is left intact; only validity is
  /// revoked, so the next analysis with that model re-extracts and overwrites
  /// the rows.
  ///
  /// Other models' rows are left alone. The state being discarded was produced
  /// by one model, and the other shelves hold unrelated work the reader may
  /// still come back to; sweeping them up would charge the full cost of a model
  /// switch to an action that never asked for one.
  ///
  /// When [notNewerThan] is given, only rows whose `updated_at` is at or before
  /// it are invalidated. Callers pass the timestamp of the state they mean to
  /// discard, so rows written afterwards — by an attempt that extracted them
  /// and then failed before saving — survive and stay reusable. Without it,
  /// every retry of a failing re-analysis would throw away the previous
  /// attempt's extractions and pay full price again.
  Future<void> invalidateWord({
    required String word,
    required String modelId,
    DateTime? notNewerThan,
  }) async {
    await _db.update(
      'fact_cache',
      {
        'content_hash': sentinelHash,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: notNewerThan == null
          ? 'word = ? AND model_id = ?'
          : 'word = ? AND model_id = ? AND updated_at <= ?',
      whereArgs: [
        word,
        modelId,
        if (notNewerThan != null) notNewerThan.toIso8601String(),
      ],
    );
  }

  /// Cascade helper: removes the cache rows for `word` under every model. Call
  /// alongside `LlmSummaryRepository.deleteAllForWord` — the summaries being
  /// deleted were the reason to keep any of the shelves.
  Future<void> deleteAllForWord({required String word}) async {
    await _db.delete('fact_cache', where: 'word = ?', whereArgs: [word]);
  }
}
