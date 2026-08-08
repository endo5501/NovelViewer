import '../domain/tts_segment.dart';
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
    this.skip = false,
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

  /// Excluded from generation, playback and export. Independent of
  /// [hasAudio]: skipping never deletes audio, so consumers must read this
  /// rather than infer it from a missing recording.
  bool skip;

  bool dbRecordExists;

  static List<TtsEditSegment> mergeSegments({
    required List<TextSegment> originalSegments,
    required List<TtsSegment> dbSegments,
  }) {
    final dbMap = <int, TtsSegment>{
      for (final row in dbSegments) row.segmentIndex: row,
    };

    return List.generate(originalSegments.length, (i) {
      final original = originalSegments[i];
      final dbRow = dbMap[i];

      if (dbRow != null) {
        return TtsEditSegment(
          segmentIndex: i,
          originalText: original.text,
          text: dbRow.text,
          textOffset: original.offset,
          textLength: original.length,
          hasAudio: dbRow.audioData != null,
          refWavPath: dbRow.refWavPath,
          memo: dbRow.memo,
          skip: dbRow.skip,
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
