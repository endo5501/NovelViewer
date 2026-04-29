import '_row_helpers.dart';
import 'tts_episode_status.dart';

class TtsEpisode {
  const TtsEpisode({
    required this.id,
    required this.fileName,
    required this.sampleRate,
    required this.status,
    required this.refWavPath,
    required this.textHash,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String fileName;
  final int sampleRate;
  final TtsEpisodeStatus status;
  final String? refWavPath;
  final String? textHash;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TtsEpisode.fromRow(Map<String, Object?> row) {
    return TtsEpisode(
      id: requireColumn(row, 'id', 'tts_episodes') as int,
      fileName: requireColumn(row, 'file_name', 'tts_episodes') as String,
      sampleRate: requireColumn(row, 'sample_rate', 'tts_episodes') as int,
      status: TtsEpisodeStatus.fromDb(
          requireColumn(row, 'status', 'tts_episodes') as String),
      refWavPath: row['ref_wav_path'] as String?,
      textHash: row['text_hash'] as String?,
      createdAt: DateTime.parse(
          requireColumn(row, 'created_at', 'tts_episodes') as String),
      updatedAt: DateTime.parse(
          requireColumn(row, 'updated_at', 'tts_episodes') as String),
    );
  }
}
