import 'package:sqflite/sqflite.dart';
import 'package:novel_viewer/features/bookmark/domain/bookmark.dart';

/// SQLite-backed access to one novel's `bookmarks` table inside its per-folder
/// `novel_data.db`. Identity within the novel is `(file_name, line_number)`;
/// the novel identity is the database the repository is bound to, so no
/// `novel_id` is passed or stored.
class BookmarkRepository {
  static const _tableName = 'bookmarks';

  final Database _db;

  BookmarkRepository(this._db);

  Future<void> add({
    required String fileName,
    int? lineNumber,
  }) async {
    // SQLite treats NULLs as distinct in UNIQUE constraints,
    // so we check for duplicates manually when lineNumber is null.
    if (lineNumber == null) {
      final alreadyExists = await exists(fileName: fileName);
      if (alreadyExists) return;
    }

    final bookmark = Bookmark(
      fileName: fileName,
      lineNumber: lineNumber,
      createdAt: DateTime.now(),
    );

    await _db.insert(
      _tableName,
      bookmark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> remove({
    required String fileName,
    int? lineNumber,
  }) async {
    if (lineNumber != null) {
      await _db.delete(
        _tableName,
        where: 'file_name = ? AND line_number = ?',
        whereArgs: [fileName, lineNumber],
      );
    } else {
      await _db.delete(
        _tableName,
        where: 'file_name = ? AND line_number IS NULL',
        whereArgs: [fileName],
      );
    }
  }

  Future<List<Bookmark>> findAll() async {
    final maps = await _db.query(
      _tableName,
      orderBy: 'created_at DESC',
    );
    return maps.map(Bookmark.fromMap).toList();
  }

  Future<List<Bookmark>> findByFile({
    required String fileName,
  }) async {
    final maps = await _db.query(
      _tableName,
      where: 'file_name = ?',
      whereArgs: [fileName],
      orderBy: 'line_number ASC',
    );
    return maps.map(Bookmark.fromMap).toList();
  }

  Future<bool> exists({
    required String fileName,
    int? lineNumber,
  }) async {
    final String where;
    final List<Object?> whereArgs;
    if (lineNumber != null) {
      where = 'file_name = ? AND line_number = ?';
      whereArgs = [fileName, lineNumber];
    } else {
      where = 'file_name = ? AND line_number IS NULL';
      whereArgs = [fileName];
    }
    final result = await _db.query(
      _tableName,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
