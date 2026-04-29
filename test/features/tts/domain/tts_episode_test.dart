import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode_status.dart';

void main() {
  group('TtsEpisode.fromRow', () {
    test('builds episode from a complete row', () {
      final row = <String, Object?>{
        'id': 42,
        'file_name': '0001_プロローグ.txt',
        'sample_rate': 24000,
        'status': 'completed',
        'ref_wav_path': '/voice/ref.wav',
        'text_hash': 'abc123',
        'created_at': '2026-04-01T00:00:00.000Z',
        'updated_at': '2026-04-02T01:23:45.000Z',
      };

      final episode = TtsEpisode.fromRow(row);

      expect(episode.id, 42);
      expect(episode.fileName, '0001_プロローグ.txt');
      expect(episode.sampleRate, 24000);
      expect(episode.status, TtsEpisodeStatus.completed);
      expect(episode.refWavPath, '/voice/ref.wav');
      expect(episode.textHash, 'abc123');
      expect(episode.createdAt, DateTime.parse('2026-04-01T00:00:00.000Z'));
      expect(episode.updatedAt, DateTime.parse('2026-04-02T01:23:45.000Z'));
    });

    test('accepts null ref_wav_path and text_hash', () {
      final row = <String, Object?>{
        'id': 1,
        'file_name': 'a.txt',
        'sample_rate': 24000,
        'status': 'generating',
        'ref_wav_path': null,
        'text_hash': null,
        'created_at': '2026-04-01T00:00:00.000Z',
        'updated_at': '2026-04-01T00:00:00.000Z',
      };

      final episode = TtsEpisode.fromRow(row);

      expect(episode.refWavPath, isNull);
      expect(episode.textHash, isNull);
      expect(episode.status, TtsEpisodeStatus.generating);
    });

    test('throws on missing required column', () {
      final row = <String, Object?>{
        'id': 1,
        // missing 'file_name'
        'sample_rate': 24000,
        'status': 'partial',
        'created_at': '2026-04-01T00:00:00.000Z',
        'updated_at': '2026-04-01T00:00:00.000Z',
      };

      expect(() => TtsEpisode.fromRow(row), throwsA(isA<FormatException>()));
    });

    test('throws on wrong type for id', () {
      final row = <String, Object?>{
        'id': '42', // string instead of int
        'file_name': 'a.txt',
        'sample_rate': 24000,
        'status': 'completed',
        'created_at': '2026-04-01T00:00:00.000Z',
        'updated_at': '2026-04-01T00:00:00.000Z',
      };

      expect(() => TtsEpisode.fromRow(row), throwsA(isA<TypeError>()));
    });

    test('throws on unknown status string', () {
      final row = <String, Object?>{
        'id': 1,
        'file_name': 'a.txt',
        'sample_rate': 24000,
        'status': 'mystery',
        'created_at': '2026-04-01T00:00:00.000Z',
        'updated_at': '2026-04-01T00:00:00.000Z',
      };

      expect(() => TtsEpisode.fromRow(row), throwsA(isA<FormatException>()));
    });

    test('maps each known status string', () {
      TtsEpisode build(String status) => TtsEpisode.fromRow({
            'id': 1,
            'file_name': 'a.txt',
            'sample_rate': 24000,
            'status': status,
            'created_at': '2026-04-01T00:00:00.000Z',
            'updated_at': '2026-04-01T00:00:00.000Z',
          });

      expect(build('generating').status, TtsEpisodeStatus.generating);
      expect(build('partial').status, TtsEpisodeStatus.partial);
      expect(build('completed').status, TtsEpisodeStatus.completed);
    });
  });
}
