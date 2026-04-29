import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/text_segmenter.dart';
import 'package:novel_viewer/features/tts/data/tts_edit_segment.dart';
import 'package:novel_viewer/features/tts/domain/tts_segment.dart';

TtsSegment _seg({
  required int segmentIndex,
  required String text,
  Uint8List? audioData,
  int? sampleCount,
  int textOffset = 0,
  int textLength = 0,
  String? refWavPath,
  String? memo,
}) {
  return TtsSegment(
    id: segmentIndex + 1,
    episodeId: 1,
    segmentIndex: segmentIndex,
    text: text,
    textOffset: textOffset,
    textLength: textLength,
    audioData: audioData,
    sampleCount: sampleCount,
    refWavPath: refWavPath,
    memo: memo,
    createdAt: DateTime.utc(2025, 1, 1),
  );
}

void main() {
  group('TtsEditSegment.mergeSegments', () {
    test('returns original segments when no DB records exist', () {
      final originals = [
        const TextSegment(text: '今日は天気です。', offset: 0, length: 8),
        const TextSegment(text: '散歩に出かけよう。', offset: 9, length: 9),
      ];

      final result = TtsEditSegment.mergeSegments(
        originalSegments: originals,
        dbSegments: const [],
      );

      expect(result, hasLength(2));
      expect(result[0].segmentIndex, 0);
      expect(result[0].text, '今日は天気です。');
      expect(result[0].originalText, '今日は天気です。');
      expect(result[0].hasAudio, false);
      expect(result[0].dbRecordExists, false);
      expect(result[1].segmentIndex, 1);
      expect(result[1].text, '散歩に出かけよう。');
    });

    test('uses DB text for segments with existing records', () {
      final originals = [
        const TextSegment(text: '山奥の一軒家', offset: 0, length: 6),
        const TextSegment(text: '散歩に出かけよう。', offset: 7, length: 9),
      ];

      final dbSegments = [
        _seg(
          segmentIndex: 0,
          text: '山奥のいっけんや',
          audioData: Uint8List.fromList([1, 2, 3]),
          refWavPath: '/path/to/voice.wav',
          memo: '読み修正',
        ),
      ];

      final result = TtsEditSegment.mergeSegments(
        originalSegments: originals,
        dbSegments: dbSegments,
      );

      expect(result[0].text, '山奥のいっけんや');
      expect(result[0].originalText, '山奥の一軒家');
      expect(result[0].hasAudio, true);
      expect(result[0].refWavPath, '/path/to/voice.wav');
      expect(result[0].memo, '読み修正');
      expect(result[0].dbRecordExists, true);

      expect(result[1].text, '散歩に出かけよう。');
      expect(result[1].hasAudio, false);
      expect(result[1].dbRecordExists, false);
    });

    test('handles DB segment with null audio_data (edited but not generated)',
        () {
      final originals = [
        const TextSegment(text: '原文テキスト。', offset: 0, length: 7),
      ];

      final dbSegments = [
        _seg(
          segmentIndex: 0,
          text: '編集済みテキスト。',
          audioData: null,
          refWavPath: null,
          memo: null,
        ),
      ];

      final result = TtsEditSegment.mergeSegments(
        originalSegments: originals,
        dbSegments: dbSegments,
      );

      expect(result[0].text, '編集済みテキスト。');
      expect(result[0].hasAudio, false);
      expect(result[0].dbRecordExists, true);
    });

    test('handles mixed state with some DB records and some without', () {
      final originals = [
        const TextSegment(text: 'セグメント0。', offset: 0, length: 6),
        const TextSegment(text: 'セグメント1。', offset: 7, length: 6),
        const TextSegment(text: 'セグメント2。', offset: 14, length: 6),
      ];

      final dbSegments = [
        _seg(
          segmentIndex: 0,
          text: 'セグメント0。',
          audioData: Uint8List(4),
          refWavPath: null,
          memo: null,
        ),
        _seg(
          segmentIndex: 2,
          text: '編集済み2。',
          audioData: null,
          refWavPath: '/voice.wav',
          memo: 'メモ',
        ),
      ];

      final result = TtsEditSegment.mergeSegments(
        originalSegments: originals,
        dbSegments: dbSegments,
      );

      expect(result[0].hasAudio, true);
      expect(result[0].dbRecordExists, true);

      expect(result[1].text, 'セグメント1。');
      expect(result[1].hasAudio, false);
      expect(result[1].dbRecordExists, false);

      expect(result[2].text, '編集済み2。');
      expect(result[2].hasAudio, false);
      expect(result[2].dbRecordExists, true);
      expect(result[2].refWavPath, '/voice.wav');
      expect(result[2].memo, 'メモ');
    });
  });
}
