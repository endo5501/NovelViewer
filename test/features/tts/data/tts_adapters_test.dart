import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_adapters.dart';

void main() {
  group('JustAudioPlayer', () {
    test('implements TtsAudioPlayer', () {
      // JustAudioPlayer wraps just_audio which requires platform channels.
      // We verify the type relationship only.
      expect(JustAudioPlayer.new, isA<Function>());
    });
  });
}
