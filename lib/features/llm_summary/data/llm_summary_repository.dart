import 'package:sqflite/sqflite.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

/// SQLite-backed access to the v5 `word_summaries` table. Snapshot rows are
/// keyed by `(folder_name, word, covered_up_to_episode)`; callers either look
/// up all snapshots for a word or upsert/delete by that triplet.
class LlmSummaryRepository {
  final Database _db;

  LlmSummaryRepository(this._db);

  static const int minWordLength = 2;

  /// Returns every snapshot row for `(folderName, word)`, sorted by
  /// `coveredUpToEpisode` ascending so the hover popup's snapshot navigator
  /// and the history panel's copy submenu can walk them in order.
  Future<List<WordSummary>> findSnapshotsForWord({
    required String folderName,
    required String word,
  }) async {
    final results = await _db.query(
      'word_summaries',
      where: 'folder_name = ? AND word = ?',
      whereArgs: [folderName, word],
      orderBy: 'covered_up_to_episode ASC',
    );
    return results.map(WordSummary.fromMap).toList();
  }

  /// Upserts a snapshot. Reject 1-character words at the repository layer so
  /// mark rendering and the history panel never have to filter them at the
  /// presentation layer.
  ///
  /// `created_at` is **preserved** across re-analyses: this is implemented as
  /// a single SQLite native upsert (`INSERT ... ON CONFLICT(...) DO UPDATE`)
  /// rather than a read-then-write pair, so a re-analysis double-tap cannot
  /// race between the read and the write and overwrite the original
  /// `created_at` with `now`. The unique index
  /// `idx_word_summaries_unique(folder_name, word, covered_up_to_episode)`
  /// is the conflict target.
  Future<void> saveSnapshot({
    required String folderName,
    required String word,
    required int coveredUpToEpisode,
    required String summary,
    String? sourceFile,
  }) async {
    if (word.runes.length < minWordLength) {
      throw ArgumentError.value(
        word,
        'word',
        'must be at least $minWordLength characters long',
      );
    }
    final now = DateTime.now().toIso8601String();
    await _db.rawInsert(
      '''
      INSERT INTO word_summaries
        (folder_name, word, covered_up_to_episode, summary, source_file,
         created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(folder_name, word, covered_up_to_episode) DO UPDATE SET
        summary = excluded.summary,
        source_file = excluded.source_file,
        updated_at = excluded.updated_at
      ''',
      [
        folderName,
        word,
        coveredUpToEpisode,
        summary,
        sourceFile,
        now,
        now,
      ],
    );
  }

  /// Returns every snapshot row in the folder, ordered by
  /// `(word, coveredUpToEpisode)` ascending. Callers that need a per-word view
  /// (e.g. the history panel) feed the result into `HistoryEntry.mergeRows`.
  Future<List<WordSummary>> findAllByFolder(String folderName) async {
    final results = await _db.query(
      'word_summaries',
      where: 'folder_name = ?',
      whereArgs: [folderName],
      orderBy: 'word ASC, covered_up_to_episode ASC',
    );
    return results.map(WordSummary.fromMap).toList();
  }

  /// Removes every snapshot row for `(folderName, word)` — i.e. drops the
  /// word from the active novel entirely. Per-snapshot deletion is not
  /// exposed; the UI deletes per word.
  Future<void> deleteAllForWord({
    required String folderName,
    required String word,
  }) async {
    await _db.delete(
      'word_summaries',
      where: 'folder_name = ? AND word = ?',
      whereArgs: [folderName, word],
    );
  }

  Future<void> deleteByFolderName(String folderName) async {
    await _db.delete(
      'word_summaries',
      where: 'folder_name = ?',
      whereArgs: [folderName],
    );
  }
}
