import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/providers/tts_export_providers.dart';
import 'package:novel_viewer/features/tts/domain/tts_segment.dart';

TtsSegment _segment({
  required int index,
  Uint8List? audioData,
  bool skip = false,
}) =>
    TtsSegment(
      id: index + 1,
      episodeId: 1,
      segmentIndex: index,
      text: '文$index。',
      textOffset: index * 4,
      textLength: 3,
      audioData: audioData,
      sampleCount: audioData == null ? null : 5,
      refWavPath: null,
      memo: null,
      skip: skip,
      createdAt: DateTime.utc(2026, 1, 1),
    );

Uint8List _wav(int marker) => Uint8List.fromList([marker, marker, marker]);

void main() {
  group('exportableWavSegments', () {
    test('collects audio in segment order', () {
      final result = exportableWavSegments([
        _segment(index: 0, audioData: _wav(1)),
        _segment(index: 1, audioData: _wav(2)),
        _segment(index: 2, audioData: _wav(3)),
      ]);

      expect(result.map((w) => w.first), [1, 2, 3]);
    });

    test('omits segments without audio', () {
      final result = exportableWavSegments([
        _segment(index: 0, audioData: _wav(1)),
        _segment(index: 1),
        _segment(index: 2, audioData: _wav(3)),
      ]);

      expect(result.map((w) => w.first), [1, 3]);
    });

    test('omits skipped segments even when they hold audio', () {
      final result = exportableWavSegments([
        _segment(index: 0, audioData: _wav(1)),
        _segment(index: 1, audioData: _wav(2), skip: true),
        _segment(index: 2, audioData: _wav(3)),
      ]);

      // Skipping keeps the recording, so filtering on audio alone would
      // silently splice a sentence the user excluded back into the MP3.
      expect(result.map((w) => w.first), [1, 3]);
    });

    test('returns empty when every segment holding audio is skipped', () {
      final result = exportableWavSegments([
        _segment(index: 0, audioData: _wav(1), skip: true),
        _segment(index: 1, audioData: _wav(2), skip: true),
      ]);

      expect(result, isEmpty);
    });

    test('returns empty for an episode with no segments', () {
      expect(exportableWavSegments([]), isEmpty);
    });
  });
}
