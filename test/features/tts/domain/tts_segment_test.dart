import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/domain/tts_segment.dart';

Map<String, Object?> _row({Object? skip}) => {
      'id': 1,
      'episode_id': 2,
      'segment_index': 3,
      'text': 'テスト文。',
      'text_offset': 0,
      'text_length': 5,
      'audio_data': Uint8List.fromList([1, 2, 3, 4]),
      'sample_count': 2,
      'ref_wav_path': 'Anna.mp3',
      'memo': 'メモ',
      'skip': skip,
      'created_at': '2026-01-01T00:00:00.000Z',
    };

void main() {
  group('TtsSegment.fromRow skip column', () {
    test('reads skip = 1 as true', () {
      final segment = TtsSegment.fromRow(_row(skip: 1));
      expect(segment.skip, isTrue);
    });

    test('reads skip = 0 as false', () {
      final segment = TtsSegment.fromRow(_row(skip: 0));
      expect(segment.skip, isFalse);
    });

    test('a skipped row keeps its audio', () {
      final segment = TtsSegment.fromRow(_row(skip: 1));
      // Skipping never deletes audio, so the DTO must surface both.
      expect(segment.skip, isTrue);
      expect(segment.audioData, isNotNull);
      expect(segment.sampleCount, 2);
    });
  });
}
