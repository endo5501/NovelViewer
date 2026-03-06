import 'package:sqflite/sqflite.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/bookmark/domain/bookmark.dart';

class BookmarkRepository {
  static const _tableName = 'bookmarks';

  final NovelDatabase _novelDatabase;

  BookmarkRepository(this._novelDatabase);

  Future<void> add({
    required String novelId,
    required String fileName,
    required String filePath,
    int? lineNumber,
  }) async {
    // SQLite treats NULLs as distinct in UNIQUE constraints,
    // so we check for duplicates manually when lineNumber is null.
    if (lineNumber == null) {
      final alreadyExists = await exists(
        novelId: novelId,
        filePath: filePath,
      );
      if (alreadyExists) return;
    }

    final bookmark = Bookmark(
      novelId: novelId,
      fileName: fileName,
      filePath: filePath,
      lineNumber: lineNumber,
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
    int? lineNumber,
  }) async {
    final db = await _novelDatabase.database;
    if (lineNumber != null) {
      await db.delete(
        _tableName,
        where: 'novel_id = ? AND file_path = ? AND line_number = ?',
        whereArgs: [novelId, filePath, lineNumber],
      );
    } else {
      await db.delete(
        _tableName,
        where: 'novel_id = ? AND file_path = ? AND line_number IS NULL',
        whereArgs: [novelId, filePath],
      );
    }
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

  Future<List<Bookmark>> findByNovelAndFile({
    required String novelId,
    required String filePath,
  }) async {
    final db = await _novelDatabase.database;
    final maps = await db.query(
      _tableName,
      where: 'novel_id = ? AND file_path = ?',
      whereArgs: [novelId, filePath],
      orderBy: 'line_number ASC',
    );
    return maps.map(Bookmark.fromMap).toList();
  }

  Future<bool> exists({
    required String novelId,
    required String filePath,
    int? lineNumber,
  }) async {
    final db = await _novelDatabase.database;
    final String where;
    final List<Object?> whereArgs;
    if (lineNumber != null) {
      where = 'novel_id = ? AND file_path = ? AND line_number = ?';
      whereArgs = [novelId, filePath, lineNumber];
    } else {
      where = 'novel_id = ? AND file_path = ? AND line_number IS NULL';
      whereArgs = [novelId, filePath];
    }
    final result = await db.query(
      _tableName,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
