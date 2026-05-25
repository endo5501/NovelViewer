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
  /// `created_at` is **preserved** across re-analyses: when an existing row
  /// matches the `(folder_name, word, coveredUpToEpisode)` triplet, its
  /// original `created_at` is reused. This keeps "when did the user first
  /// cache this snapshot" stable even though `ConflictAlgorithm.replace`
  /// physically DELETEs+INSERTs the row.
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
    final existing = await _db.query(
      'word_summaries',
      columns: ['created_at'],
      where: 'folder_name = ? AND word = ? AND covered_up_to_episode = ?',
      whereArgs: [folderName, word, coveredUpToEpisode],
      limit: 1,
    );
    final createdAt = existing.isNotEmpty
        ? existing.first['created_at'] as String
        : now;
    await _db.insert(
      'word_summaries',
      {
        'folder_name': folderName,
        'word': word,
        'covered_up_to_episode': coveredUpToEpisode,
        'summary': summary,
        'source_file': sourceFile,
        'created_at': createdAt,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
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
