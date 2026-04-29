import 'dart:typed_data';

import '../domain/tts_episode.dart';
import '../domain/tts_episode_status.dart';
import '../domain/tts_segment.dart';
import 'tts_audio_database.dart';

class TtsAudioRepository {
  final TtsAudioDatabase _database;
  final void Function()? _onEpisodeDeleted;

  /// [onEpisodeDeleted] is invoked after `deleteEpisode` finishes. The
  /// streaming/edit/UI layer wires this to `VacuumLifecycle.markDirty(folder)`
  /// so the underlying SQLite file is reclaimed at app exit instead of
  /// blocking the UI thread inside the delete call.
  TtsAudioRepository(this._database, {void Function()? onEpisodeDeleted})
      : _onEpisodeDeleted = onEpisodeDeleted;

  Future<int> createEpisode({
    required String fileName,
    required int sampleRate,
    required TtsEpisodeStatus status,
    String? refWavPath,
    String? textHash,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return db.insert('tts_episodes', {
      'file_name': fileName,
      'sample_rate': sampleRate,
      'status': status.toDb(),
      'ref_wav_path': refWavPath,
      'text_hash': textHash,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateEpisodeStatus(
      int episodeId, TtsEpisodeStatus status) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'tts_episodes',
      {'status': status.toDb(), 'updated_at': now},
      where: 'id = ?',
      whereArgs: [episodeId],
    );
  }

  Future<void> updateEpisodeTextHash(int episodeId, String textHash) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'tts_episodes',
      {'text_hash': textHash, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [episodeId],
    );
  }

  Future<TtsEpisode?> findEpisodeByFileName(String fileName) async {
    final db = await _database.database;
    final rows = await db.query(
      'tts_episodes',
      where: 'file_name = ?',
      whereArgs: [fileName],
      limit: 1,
    );
    return rows.isEmpty ? null : TtsEpisode.fromRow(rows.first);
  }

  Future<void> insertSegment({
    required int episodeId,
    required int segmentIndex,
    required String text,
    required int textOffset,
    required int textLength,
    Uint8List? audioData,
    int? sampleCount,
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

  Future<List<TtsSegment>> getSegments(int episodeId) async {
    final db = await _database.database;
    final rows = await db.query(
      'tts_segments',
      where: 'episode_id = ?',
      whereArgs: [episodeId],
      orderBy: 'segment_index ASC',
    );
    return [for (final row in rows) TtsSegment.fromRow(row)];
  }

  Future<TtsSegment> getSegmentByIndex(int episodeId, int segmentIndex) async {
    final db = await _database.database;
    final rows = await db.query(
      'tts_segments',
      where: 'episode_id = ? AND segment_index = ?',
      whereArgs: [episodeId, segmentIndex],
      limit: 1,
    );
    return TtsSegment.fromRow(rows.first);
  }

  Future<TtsSegment?> findSegmentByOffset(
      int episodeId, int textOffset) async {
    final db = await _database.database;
    final rows = await db.query(
      'tts_segments',
      where: 'episode_id = ? AND text_offset <= ?',
      whereArgs: [episodeId, textOffset],
      orderBy: 'text_offset DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : TtsSegment.fromRow(rows.first);
  }

  Future<int> getSegmentCount(int episodeId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tts_segments WHERE episode_id = ?',
      [episodeId],
    );
    return result.first['count'] as int;
  }

  Future<void> updateSegmentText(
      int episodeId, int segmentIndex, String newText) async {
    final db = await _database.database;
    await db.update(
      'tts_segments',
      {'text': newText, 'audio_data': null, 'sample_count': null},
      where: 'episode_id = ? AND segment_index = ?',
      whereArgs: [episodeId, segmentIndex],
    );
  }

  Future<void> updateSegmentAudio(
      int episodeId, int segmentIndex, Uint8List audioData, int sampleCount) async {
    final db = await _database.database;
    await db.update(
      'tts_segments',
      {'audio_data': audioData, 'sample_count': sampleCount},
      where: 'episode_id = ? AND segment_index = ?',
      whereArgs: [episodeId, segmentIndex],
    );
  }

  Future<void> updateSegmentRefWavPath(
      int episodeId, int segmentIndex, String? refWavPath) async {
    final db = await _database.database;
    await db.update(
      'tts_segments',
      {'ref_wav_path': refWavPath},
      where: 'episode_id = ? AND segment_index = ?',
      whereArgs: [episodeId, segmentIndex],
    );
  }

  Future<void> updateSegmentMemo(
      int episodeId, int segmentIndex, String? memo) async {
    final db = await _database.database;
    await db.update(
      'tts_segments',
      {'memo': memo},
      where: 'episode_id = ? AND segment_index = ?',
      whereArgs: [episodeId, segmentIndex],
    );
  }

  Future<void> deleteSegment(int episodeId, int segmentIndex) async {
    final db = await _database.database;
    await db.delete(
      'tts_segments',
      where: 'episode_id = ? AND segment_index = ?',
      whereArgs: [episodeId, segmentIndex],
    );
  }

  Future<int> getGeneratedSegmentCount(int episodeId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tts_segments WHERE episode_id = ? AND audio_data IS NOT NULL',
      [episodeId],
    );
    return result.first['count'] as int;
  }

  Future<Map<String, TtsEpisodeStatus>> getAllEpisodeStatuses() async {
    final db = await _database.database;
    final rows = await db.query(
      'tts_episodes',
      columns: ['file_name', 'status'],
    );
    return {
      for (final row in rows)
        row['file_name'] as String:
            TtsEpisodeStatus.fromDb(row['status'] as String),
    };
  }

  Future<void> deleteEpisode(int episodeId) async {
    final db = await _database.database;
    await db.delete(
      'tts_episodes',
      where: 'id = ?',
      whereArgs: [episodeId],
    );
    // Defer reclaim to app exit via VacuumLifecycle to avoid blocking the
    // UI thread (incremental_vacuum on a 100MB+ DB stalls hundreds of ms).
    _onEpisodeDeleted?.call();
  }
}
