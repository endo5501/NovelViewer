import 'package:sqflite/sqflite.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

class LlmSummaryRepository {
  final Database _db;

  LlmSummaryRepository(this._db);

  Future<WordSummary?> findSummary({
    required String folderName,
    required String word,
    required SummaryType summaryType,
  }) async {
    final results = await _db.query(
      'word_summaries',
      where: 'folder_name = ? AND word = ? AND summary_type = ?',
      whereArgs: [folderName, word, summaryType.toDbString()],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return WordSummary.fromMap(results.first);
  }

  Future<void> saveSummary({
    required String folderName,
    required String word,
    required SummaryType summaryType,
    required String summary,
    String? sourceFile,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.insert(
      'word_summaries',
      {
        'folder_name': folderName,
        'word': word,
        'summary_type': summaryType.toDbString(),
        'summary': summary,
        'source_file': sourceFile,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSummary({
    required String folderName,
    required String word,
    required SummaryType summaryType,
  }) async {
    await _db.delete(
      'word_summaries',
      where: 'folder_name = ? AND word = ? AND summary_type = ?',
      whereArgs: [folderName, word, summaryType.toDbString()],
    );
  }
}
