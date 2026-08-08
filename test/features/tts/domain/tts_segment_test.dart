import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/domain/tts_segment.dart';

void main() {
  group('TtsSegment.fromRow', () {
    test('builds segment from a complete row with audio', () {
      final audio = Uint8List.fromList([1, 2, 3, 4]);
      final row = <String, Object?>{
        'id': 7,
        'episode_id': 3,
        'segment_index': 2,
        'text': 'こんにちは。',
        'text_offset': 10,
        'text_length': 6,
        'audio_data': audio,
        'sample_count': 1024,
        'ref_wav_path': '/voice/ref.wav',
        'memo': '感情的に',
        'skip': 0,
        'created_at': '2026-04-01T00:00:00.000Z',
      };

      final segment = TtsSegment.fromRow(row);

      expect(segment.id, 7);
      expect(segment.episodeId, 3);
      expect(segment.segmentIndex, 2);
      expect(segment.text, 'こんにちは。');
      expect(segment.textOffset, 10);
      expect(segment.textLength, 6);
      expect(segment.audioData, isA<Uint8List>());
      expect(segment.audioData!.toList(), [1, 2, 3, 4]);
      expect(segment.sampleCount, 1024);
      expect(segment.refWavPath, '/voice/ref.wav');
      expect(segment.memo, '感情的に');
      expect(segment.skip, isFalse);
      expect(segment.createdAt, DateTime.parse('2026-04-01T00:00:00.000Z'));
    });

    test('accepts NULL audio_data and sample_count', () {
      final row = <String, Object?>{
        'id': 7,
        'episode_id': 3,
        'segment_index': 0,
        'text': 'テスト。',
        'text_offset': 0,
        'text_length': 4,
        'audio_data': null,
        'sample_count': null,
        'ref_wav_path': null,
        'memo': null,
        'skip': 0,
        'created_at': '2026-04-01T00:00:00.000Z',
      };

      final segment = TtsSegment.fromRow(row);

      expect(segment.audioData, isNull);
      expect(segment.sampleCount, isNull);
      expect(segment.refWavPath, isNull);
      expect(segment.memo, isNull);
    });

    test('accepts audio_data stored as List<int> from sqflite', () {
      final row = <String, Object?>{
        'id': 7,
        'episode_id': 3,
        'segment_index': 0,
        'text': 'テスト。',
        'text_offset': 0,
        'text_length': 4,
        'audio_data': <int>[10, 20, 30],
        'sample_count': 100,
        'ref_wav_path': null,
        'memo': null,
        'skip': 0,
        'created_at': '2026-04-01T00:00:00.000Z',
      };

      final segment = TtsSegment.fromRow(row);

      expect(segment.audioData, isA<Uint8List>());
      expect(segment.audioData!.toList(), [10, 20, 30]);
    });

    test('throws on missing required column', () {
      final row = <String, Object?>{
        'id': 7,
        'episode_id': 3,
        // missing 'segment_index'
        'text': 'テスト',
        'text_offset': 0,
        'text_length': 4,
        'created_at': '2026-04-01T00:00:00.000Z',
      };

      expect(() => TtsSegment.fromRow(row), throwsA(isA<FormatException>()));
    });
  });

  group('TtsSegment.fromRow skip column', () {
    Map<String, Object?> row({Object? skip}) => {
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

    test('reads skip = 1 as true', () {
      expect(TtsSegment.fromRow(row(skip: 1)).skip, isTrue);
    });

    test('reads skip = 0 as false', () {
      expect(TtsSegment.fromRow(row(skip: 0)).skip, isFalse);
    });

    test('a skipped row keeps its audio', () {
      final segment = TtsSegment.fromRow(row(skip: 1));
      // Skipping never deletes audio, so the DTO must surface both.
      expect(segment.skip, isTrue);
      expect(segment.audioData, isNotNull);
      expect(segment.sampleCount, 2);
    });

    test('throws when the skip column is missing', () {
      final incomplete = row(skip: 0)..remove('skip');
      expect(() => TtsSegment.fromRow(incomplete),
          throwsA(isA<FormatException>()));
    });
  });
}
