import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';

void main() {
  group('TtsEngine', () {
    test('TtsSynthesisResult holds audio data and sample rate', () {
      final audio = Float32List.fromList([0.1, 0.2, -0.3]);
      final result = TtsSynthesisResult(audio: audio, sampleRate: 24000);

      expect(result.audio, audio);
      expect(result.sampleRate, 24000);
      expect(result.audio.length, 3);
    });

    test('TtsEngineException contains error message', () {
      final exception = TtsEngineException('model load failed');
      expect(exception.message, 'model load failed');
      expect(exception.toString(), contains('model load failed'));
    });
  });
}
