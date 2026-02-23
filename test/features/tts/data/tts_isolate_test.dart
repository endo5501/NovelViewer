import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';
import 'package:novel_viewer/features/tts/data/tts_isolate.dart';

void main() {
  group('TtsIsolateMessage', () {
    test('LoadModelMessage holds model directory and thread count', () {
      final msg = LoadModelMessage(modelDir: '/path/to/models', nThreads: 8);
      expect(msg.modelDir, '/path/to/models');
      expect(msg.nThreads, 8);
    });

    test('LoadModelMessage holds languageId with explicit value', () {
      final msg = LoadModelMessage(
        modelDir: '/path/to/models',
        languageId: 2050,
      );
      expect(msg.languageId, 2050);
    });

    test('LoadModelMessage defaults languageId to Japanese', () {
      final msg = LoadModelMessage(modelDir: '/path/to/models');
      expect(msg.languageId, TtsEngine.languageJapanese);
    });

    test('SynthesizeMessage holds text', () {
      final msg = SynthesizeMessage(text: 'こんにちは');
      expect(msg.text, 'こんにちは');
      expect(msg.refWavPath, isNull);
    });

    test('SynthesizeMessage holds text and wav path', () {
      final msg = SynthesizeMessage(
        text: 'こんにちは',
        refWavPath: '/path/to/ref.wav',
      );
      expect(msg.text, 'こんにちは');
      expect(msg.refWavPath, '/path/to/ref.wav');
    });

    test('DisposeMessage is a simple marker', () {
      final msg = DisposeMessage();
      expect(msg, isNotNull);
    });
  });

  group('TtsIsolateResponse', () {
    test('ModelLoadedResponse indicates success', () {
      final response = ModelLoadedResponse(success: true);
      expect(response.success, isTrue);
      expect(response.error, isNull);
    });

    test('ModelLoadedResponse indicates failure with error', () {
      final response = ModelLoadedResponse(
        success: false,
        error: 'model not found',
      );
      expect(response.success, isFalse);
      expect(response.error, 'model not found');
    });

    test('SynthesisResultResponse holds audio data', () {
      final audio = Float32List.fromList([0.1, 0.2, 0.3]);
      final response = SynthesisResultResponse(
        audio: audio,
        sampleRate: 24000,
      );
      expect(response.audio!.length, 3);
      expect(response.sampleRate, 24000);
      expect(response.error, isNull);
    });

    test('SynthesisResultResponse holds error', () {
      final response = SynthesisResultResponse(
        audio: null,
        sampleRate: 0,
        error: 'synthesis failed',
      );
      expect(response.audio, isNull);
      expect(response.error, 'synthesis failed');
    });
  });

  group('TtsIsolate - graceful shutdown', () {
    test('dispose returns Future<void>', () {
      final ttsIsolate = TtsIsolate();
      // dispose() must return Future<void> (not void)
      final result = ttsIsolate.dispose();
      expect(result, isA<Future<void>>());
    });

    test('spawn and dispose completes gracefully', () async {
      final ttsIsolate = TtsIsolate();
      await ttsIsolate.spawn();
      // Should complete without error (isolate processes DisposeMessage and exits)
      await ttsIsolate.dispose();
    });

    test('dispose without spawn completes safely', () async {
      final ttsIsolate = TtsIsolate();
      await ttsIsolate.dispose();
    });

    test('double dispose is safe', () async {
      final ttsIsolate = TtsIsolate();
      await ttsIsolate.spawn();
      await ttsIsolate.dispose();
      await ttsIsolate.dispose();
    });

    test('dispose completes within timeout', () async {
      final ttsIsolate = TtsIsolate();
      await ttsIsolate.spawn();

      // Dispose should complete well within the 2 second timeout
      await ttsIsolate.dispose().timeout(const Duration(seconds: 3));
    });
  });
}
