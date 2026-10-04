import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_reference/domain/reference_graph.dart';
import 'package:sqflite/sqflite.dart';

/// Thrown when saving reference sources would let a novel reach itself by
/// following them.
class ReferenceCycleException implements Exception {
  const ReferenceCycleException(this.child);

  final String child;

  @override
  String toString() =>
      'ReferenceCycleException: reference sources of $child would form a cycle';
}

/// Reference-source relations in the global `novel_metadata.db`.
///
/// The table is small, so readers take every relation at once and work on the
/// graph in memory (see `reference_graph.dart`).
class NovelReferenceRepository {
  static const _table = 'novel_reference_sources';

  final NovelDatabase _novelDatabase;

  NovelReferenceRepository(this._novelDatabase);

  Future<List<ReferenceRelation>> findAll() async {
    final db = await _novelDatabase.database;
    return _readAll(db);
  }

  /// Makes [parents] exactly the direct reference sources of [child].
  ///
  /// The cycle check runs here, against the graph as it would be after the
  /// save, rather than being left to the dialog that hides cyclic candidates:
  /// a stored cycle would make every novel on it read the others forever.
  Future<void> replaceParents(String child, Iterable<String> parents) async {
    final db = await _novelDatabase.database;
    await db.transaction((txn) async {
      await txn.delete(
        _table,
        where: 'child_folder_name = ?',
        whereArgs: [child],
      );
      final now = DateTime.now().toIso8601String();
      for (final parent in parents.toSet()) {
        await txn.insert(_table, {
          'child_folder_name': child,
          'parent_folder_name': parent,
          'created_at': now,
        });
      }
      if (hasCycle(await _readAll(txn))) {
        throw ReferenceCycleException(child);
      }
    });
  }

  /// Removes every relation [folderName] takes part in, as child or parent.
  Future<void> deleteAllFor(String folderName, {DatabaseExecutor? txn}) async {
    final executor = txn ?? await _novelDatabase.database;
    await executor.delete(
      _table,
      where: 'child_folder_name = ? OR parent_folder_name = ?',
      whereArgs: [folderName, folderName],
    );
  }

  static Future<List<ReferenceRelation>> _readAll(
    DatabaseExecutor executor,
  ) async {
    final rows = await executor.query(
      _table,
      orderBy: 'child_folder_name, parent_folder_name',
    );
    return [
      for (final row in rows)
        ReferenceRelation(
          child: row['child_folder_name'] as String,
          parent: row['parent_folder_name'] as String,
        ),
    ];
  }
}
