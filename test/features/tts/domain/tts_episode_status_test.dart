import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode_status.dart';

void main() {
  group('TtsEpisodeStatus.fromDb', () {
    test('maps "generating" to TtsEpisodeStatus.generating', () {
      expect(TtsEpisodeStatus.fromDb('generating'),
          TtsEpisodeStatus.generating);
    });

    test('maps "partial" to TtsEpisodeStatus.partial', () {
      expect(TtsEpisodeStatus.fromDb('partial'), TtsEpisodeStatus.partial);
    });

    test('maps "completed" to TtsEpisodeStatus.completed', () {
      expect(TtsEpisodeStatus.fromDb('completed'),
          TtsEpisodeStatus.completed);
    });

    test('throws FormatException on unknown string', () {
      expect(() => TtsEpisodeStatus.fromDb('invalid'),
          throwsA(isA<FormatException>()));
    });

    test('throws FormatException on empty string', () {
      expect(() => TtsEpisodeStatus.fromDb(''),
          throwsA(isA<FormatException>()));
    });
  });

  group('TtsEpisodeStatus.toDb', () {
    test('roundtrips generating', () {
      expect(TtsEpisodeStatus.fromDb(TtsEpisodeStatus.generating.toDb()),
          TtsEpisodeStatus.generating);
    });

    test('roundtrips partial', () {
      expect(TtsEpisodeStatus.fromDb(TtsEpisodeStatus.partial.toDb()),
          TtsEpisodeStatus.partial);
    });

    test('roundtrips completed', () {
      expect(TtsEpisodeStatus.fromDb(TtsEpisodeStatus.completed.toDb()),
          TtsEpisodeStatus.completed);
    });

    test('toDb returns expected literal strings', () {
      expect(TtsEpisodeStatus.generating.toDb(), 'generating');
      expect(TtsEpisodeStatus.partial.toDb(), 'partial');
      expect(TtsEpisodeStatus.completed.toDb(), 'completed');
    });
  });
}
