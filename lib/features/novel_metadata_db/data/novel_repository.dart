import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';

class NovelRepository {
  final NovelDatabase _novelDatabase;

  NovelRepository(this._novelDatabase);

  Future<void> upsert(NovelMetadata metadata) async {
    final db = await _novelDatabase.database;
    final existing = await findBySiteAndNovelId(
      metadata.siteType,
      metadata.novelId,
    );
    if (existing != null) {
      await db.update(
        'novels',
        {
          'title': metadata.title,
          'url': metadata.url,
          'episode_count': metadata.episodeCount,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      await db.insert('novels', metadata.toMap());
    }
  }

  Future<List<NovelMetadata>> findAll() async {
    final db = await _novelDatabase.database;
    final maps = await db.query('novels', orderBy: 'title ASC');
    return maps.map(NovelMetadata.fromMap).toList();
  }

  Future<NovelMetadata?> _findOne({
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await _novelDatabase.database;
    final maps = await db.query(
      'novels',
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    return maps.isEmpty ? null : NovelMetadata.fromMap(maps.first);
  }

  Future<NovelMetadata?> findByFolderName(String folderName) =>
      _findOne(where: 'folder_name = ?', whereArgs: [folderName]);

  Future<NovelMetadata?> findBySiteAndNovelId(
    String siteType,
    String novelId,
  ) =>
      _findOne(
        where: 'site_type = ? AND novel_id = ?',
        whereArgs: [siteType, novelId],
      );
}
