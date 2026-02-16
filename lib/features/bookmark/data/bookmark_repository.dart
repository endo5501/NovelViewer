import 'package:sqflite/sqflite.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/bookmark/domain/bookmark.dart';

class BookmarkRepository {
  static const _tableName = 'bookmarks';
  static const _whereNovelAndPath = 'novel_id = ? AND file_path = ?';

  final NovelDatabase _novelDatabase;

  BookmarkRepository(this._novelDatabase);

  Future<void> add({
    required String novelId,
    required String fileName,
    required String filePath,
  }) async {
    final bookmark = Bookmark(
      novelId: novelId,
      fileName: fileName,
      filePath: filePath,
      createdAt: DateTime.now(),
    );

    final db = await _novelDatabase.database;
    await db.insert(
      _tableName,
      bookmark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> remove({
    required String novelId,
    required String filePath,
  }) async {
    final db = await _novelDatabase.database;
    await db.delete(
      _tableName,
      where: _whereNovelAndPath,
      whereArgs: [novelId, filePath],
    );
  }

  Future<List<Bookmark>> findByNovel(String novelId) async {
    final db = await _novelDatabase.database;
    final maps = await db.query(
      _tableName,
      where: 'novel_id = ?',
      whereArgs: [novelId],
      orderBy: 'created_at DESC',
    );
    return maps.map(Bookmark.fromMap).toList();
  }

  Future<bool> exists({
    required String novelId,
    required String filePath,
  }) async {
    final db = await _novelDatabase.database;
    final result = await db.query(
      _tableName,
      where: _whereNovelAndPath,
      whereArgs: [novelId, filePath],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
