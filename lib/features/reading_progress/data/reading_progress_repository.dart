import 'package:sqflite/sqflite.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';

class ReadingProgressRepository {
  static const _tableName = 'reading_progress';

  final NovelDatabase _novelDatabase;

  ReadingProgressRepository(this._novelDatabase);

  Future<void> upsert({
    required String novelId,
    required String fileName,
  }) async {
    final db = await _novelDatabase.database;
    await db.insert(
      _tableName,
      {
        'novel_id': novelId,
        'file_name': fileName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ReadingProgress?> findByNovelId(String novelId) async {
    final db = await _novelDatabase.database;
    final rows = await db.query(
      _tableName,
      where: 'novel_id = ?',
      whereArgs: [novelId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReadingProgress.fromMap(rows.first);
  }

  Future<void> deleteByNovelId(String novelId, {DatabaseExecutor? txn}) async {
    final executor = txn ?? await _novelDatabase.database;
    await executor.delete(
      _tableName,
      where: 'novel_id = ?',
      whereArgs: [novelId],
    );
  }
}
