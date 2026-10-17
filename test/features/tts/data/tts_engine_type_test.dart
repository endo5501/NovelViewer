import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';

void main() {
  group('TtsEngineType', () {
    test('qwen3 has label Qwen3-TTS', () {
      expect(TtsEngineType.qwen3.label, 'Qwen3-TTS');
    });

    test('piper has label Piper', () {
      expect(TtsEngineType.piper.label, 'Piper');
    });

    test('irodori has label Irodori-TTS', () {
      expect(TtsEngineType.irodori.label, 'Irodori-TTS');
    });

    test('has exactly three values', () {
      expect(TtsEngineType.values.length, 3);
    });

    test('only the engines that clone a voice use reference audio', () {
      // Piper synthesizes from its own fixed voice; a per-segment reference
      // has no effect on it (spec tts-edit-screen).
      expect(TtsEngineType.qwen3.usesReferenceVoice, isTrue);
      expect(TtsEngineType.irodori.usesReferenceVoice, isTrue);
      expect(TtsEngineType.piper.usesReferenceVoice, isFalse);
    });

    test('name is used for persistence', () {
      expect(TtsEngineType.irodori.name, 'irodori');
    });
  });
}
