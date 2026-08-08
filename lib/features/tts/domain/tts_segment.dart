import 'dart:typed_data';

import '_row_helpers.dart';

class TtsSegment {
  const TtsSegment({
    required this.id,
    required this.episodeId,
    required this.segmentIndex,
    required this.text,
    required this.textOffset,
    required this.textLength,
    required this.audioData,
    required this.sampleCount,
    required this.refWavPath,
    required this.memo,
    required this.skip,
    required this.createdAt,
  });

  final int id;
  final int episodeId;
  final int segmentIndex;
  final String text;
  final int textOffset;
  final int textLength;
  final Uint8List? audioData;
  final int? sampleCount;
  final String? refWavPath;
  final String? memo;

  /// Whether this segment is excluded from synthesis, playback and export.
  ///
  /// Independent of [audioData]: marking a segment as skipped never deletes
  /// its audio, so consumers must check this flag rather than infer the
  /// decision from the absence of audio.
  final bool skip;

  final DateTime createdAt;

  factory TtsSegment.fromRow(Map<String, Object?> row) {
    final rawAudio = row['audio_data'];
    final Uint8List? audioData = rawAudio == null
        ? null
        : (rawAudio is Uint8List
            ? rawAudio
            : Uint8List.fromList(rawAudio as List<int>));

    return TtsSegment(
      id: requireColumn(row, 'id', 'tts_segments') as int,
      episodeId: requireColumn(row, 'episode_id', 'tts_segments') as int,
      segmentIndex:
          requireColumn(row, 'segment_index', 'tts_segments') as int,
      text: requireColumn(row, 'text', 'tts_segments') as String,
      textOffset: requireColumn(row, 'text_offset', 'tts_segments') as int,
      textLength: requireColumn(row, 'text_length', 'tts_segments') as int,
      audioData: audioData,
      sampleCount: row['sample_count'] as int?,
      refWavPath: row['ref_wav_path'] as String?,
      memo: row['memo'] as String?,
      skip: (requireColumn(row, 'skip', 'tts_segments') as int) != 0,
      createdAt: DateTime.parse(
          requireColumn(row, 'created_at', 'tts_segments') as String),
    );
  }
}
