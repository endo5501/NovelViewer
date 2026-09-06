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
    await db.transaction((txn) async {
      final rows = await txn.query(
        _tableName,
        where: 'novel_id = ?',
        whereArgs: [novelId],
        limit: 1,
      );
      final sameFile = rows.isNotEmpty && rows.first['file_name'] == fileName;
      await txn.insert(_tableName, {
        'novel_id': novelId,
        'file_name': fileName,
        'updated_at': DateTime.now().toIso8601String(),
        'body_offset': sameFile ? rows.first['body_offset'] : 0,
        'body_hash': sameFile ? rows.first['body_hash'] : null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
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

  Future<void> savePosition({
    required String novelId,
    required String fileName,
    required int bodyOffset,
    required String bodyHash,
  }) async {
    final db = await _novelDatabase.database;
    // Only update a still-selected file; never recreate deleted history.
    await db.update(
      _tableName,
      {
        'body_offset': bodyOffset,
        'body_hash': bodyHash,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'novel_id = ? AND file_name = ?',
      whereArgs: [novelId, fileName],
    );
  }

  Future<ReadingProgress?> findLatest() async {
    final db = await _novelDatabase.database;
    final rows = await db.query(
      _tableName,
      orderBy: 'updated_at DESC, novel_id ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : ReadingProgress.fromMap(rows.first);
  }

  /// Returns every stored reading progress row in a single query so callers
  /// (e.g. the file browser badge) can render per-novel progress for many
  /// novels without issuing one [findByNovelId] per novel.
  Future<List<ReadingProgress>> findAll() async {
    final db = await _novelDatabase.database;
    final rows = await db.query(_tableName);
    return rows.map(ReadingProgress.fromMap).toList();
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
