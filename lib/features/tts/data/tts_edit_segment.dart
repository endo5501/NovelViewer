import 'text_segmenter.dart';

class TtsEditSegment {
  TtsEditSegment({
    required this.segmentIndex,
    required this.originalText,
    required this.text,
    required this.textOffset,
    required this.textLength,
    this.hasAudio = false,
    this.refWavPath,
    this.memo,
    this.dbRecordExists = false,
  });

  final int segmentIndex;
  final String originalText;
  String text;
  final int textOffset;
  final int textLength;
  bool hasAudio;
  String? refWavPath;
  String? memo;
  bool dbRecordExists;

  static List<TtsEditSegment> mergeSegments({
    required List<TextSegment> originalSegments,
    required List<Map<String, Object?>> dbSegments,
  }) {
    final dbMap = <int, Map<String, Object?>>{};
    for (final row in dbSegments) {
      dbMap[row['segment_index'] as int] = row;
    }

    return List.generate(originalSegments.length, (i) {
      final original = originalSegments[i];
      final dbRow = dbMap[i];

      if (dbRow != null) {
        return TtsEditSegment(
          segmentIndex: i,
          originalText: original.text,
          text: dbRow['text'] as String,
          textOffset: original.offset,
          textLength: original.length,
          hasAudio: dbRow['audio_data'] != null,
          refWavPath: dbRow['ref_wav_path'] as String?,
          memo: dbRow['memo'] as String?,
          dbRecordExists: true,
        );
      }

      return TtsEditSegment(
        segmentIndex: i,
        originalText: original.text,
        text: original.text,
        textOffset: original.offset,
        textLength: original.length,
      );
    });
  }
}
