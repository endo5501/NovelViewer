import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';
import 'package:novel_viewer/features/episode_cache/domain/episode_cache.dart';
import 'package:sqflite/sqflite.dart';

class EpisodeCacheRepository {
  final EpisodeCacheDatabase _database;

  EpisodeCacheRepository(this._database);

  Future<void> upsert(EpisodeCache cache) async {
    final db = await _database.database;
    await db.insert(
      'episode_cache',
      cache.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<EpisodeCache?> findByUrl(String url) async {
    final db = await _database.database;
    final rows = await db.query(
      'episode_cache',
      where: 'url = ?',
      whereArgs: [url],
      limit: 1,
    );
    return rows.isEmpty ? null : EpisodeCache.fromMap(rows.first);
  }

  Future<Map<String, EpisodeCache>> getAllAsMap() async {
    final db = await _database.database;
    final rows = await db.query('episode_cache');
    return {
      for (final row in rows)
        row['url'] as String: EpisodeCache.fromMap(row),
    };
  }
}
