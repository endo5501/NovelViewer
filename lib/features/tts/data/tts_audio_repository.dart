import 'dart:typed_data';

import 'tts_audio_database.dart';

class TtsAudioRepository {
  final TtsAudioDatabase _database;

  TtsAudioRepository(this._database);

  Future<int> createEpisode({
    required String fileName,
    required int sampleRate,
    required String status,
    String? refWavPath,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return db.insert('tts_episodes', {
      'file_name': fileName,
      'sample_rate': sampleRate,
      'status': status,
      'ref_wav_path': refWavPath,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateEpisodeStatus(int episodeId, String status) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'tts_episodes',
      {'status': status, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [episodeId],
    );
  }

  Future<Map<String, Object?>?> findEpisodeByFileName(
      String fileName) async {
    final db = await _database.database;
    final rows = await db.query(
      'tts_episodes',
      where: 'file_name = ?',
      whereArgs: [fileName],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> insertSegment({
    required int episodeId,
    required int segmentIndex,
    required String text,
    required int textOffset,
    required int textLength,
    required Uint8List audioData,
    required int sampleCount,
    String? refWavPath,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('tts_segments', {
      'episode_id': episodeId,
      'segment_index': segmentIndex,
      'text': text,
      'text_offset': textOffset,
      'text_length': textLength,
      'audio_data': audioData,
      'sample_count': sampleCount,
      'ref_wav_path': refWavPath,
      'created_at': now,
    });
  }

  Future<List<Map<String, Object?>>> getSegments(int episodeId) async {
    final db = await _database.database;
    return db.query(
      'tts_segments',
      where: 'episode_id = ?',
      whereArgs: [episodeId],
      orderBy: 'segment_index ASC',
    );
  }

  Future<Map<String, Object?>?> findSegmentByOffset(
      int episodeId, int textOffset) async {
    final db = await _database.database;
    final rows = await db.query(
      'tts_segments',
      where: 'episode_id = ? AND text_offset <= ?',
      whereArgs: [episodeId, textOffset],
      orderBy: 'text_offset DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> getSegmentCount(int episodeId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tts_segments WHERE episode_id = ?',
      [episodeId],
    );
    return result.first['count'] as int;
  }

  Future<void> deleteEpisode(int episodeId) async {
    final db = await _database.database;
    await db.delete(
      'tts_episodes',
      where: 'id = ?',
      whereArgs: [episodeId],
    );
  }
}
