// ignore_for_file: prefer_function_declarations_over_variables

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';
import 'package:novel_viewer/features/tts/data/tts_native_bindings.dart';

/// Mock bindings for testing TtsEngine without loading native library.
class MockTtsNativeBindings extends TtsNativeBindings {
  MockTtsNativeBindings() : super(DynamicLibrary.process());

  int? lastSetLanguageId;
  Pointer<Void> lastSetLanguageCtx = nullptr;

  @override
  // ignore: overridden_fields
  late final void Function(Pointer<Void>, int) setLanguage =
      (Pointer<Void> ctx, int languageId) {
    lastSetLanguageCtx = ctx;
    lastSetLanguageId = languageId;
  };

  Pointer<Void> _fakeCtx = nullptr;
  int _isLoadedResult = 0;

  void setFakeContext(Pointer<Void> ctx, {bool loaded = true}) {
    _fakeCtx = ctx;
    _isLoadedResult = loaded ? 1 : 0;
  }

  @override
  // ignore: overridden_fields
  late final Pointer<Void> Function(Pointer<Utf8>, int) init =
      (Pointer<Utf8> modelDir, int nThreads) => _fakeCtx;

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>) isLoaded =
      (Pointer<Void> ctx) => _isLoadedResult;

  @override
  // ignore: overridden_fields
  late final void Function(Pointer<Void>) free = (Pointer<Void> ctx) {};
}

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
      const exception = TtsEngineException('model load failed');
      expect(exception.message, 'model load failed');
      expect(exception.toString(), contains('model load failed'));
    });

    test('languageJapanese constant equals 2058', () {
      expect(TtsEngine.languageJapanese, 2058);
    });
  });

  group('TtsEngine - setLanguage', () {
    late MockTtsNativeBindings mockBindings;
    late TtsEngine engine;

    setUp(() {
      mockBindings = MockTtsNativeBindings();
      engine = TtsEngine(mockBindings);
    });

    test('setLanguage calls native binding with correct language ID', () {
      // Simulate a loaded context
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model/dir');

      engine.setLanguage(TtsEngine.languageJapanese);

      expect(mockBindings.lastSetLanguageId, 2058);
    });

    test('setLanguage throws when model is not loaded', () {
      expect(
        () => engine.setLanguage(TtsEngine.languageJapanese),
        throwsA(isA<TtsEngineException>()),
      );
    });
  });

  group('TtsEngine - synthesize with optional params', () {
    test('synthesize with instruct throws when model is not loaded', () {
      final mockBindings = MockTtsNativeBindings();
      final engine = TtsEngine(mockBindings);

      expect(
        () => engine.synthesize('text', instruct: 'happy'),
        throwsA(isA<TtsEngineException>()),
      );
    });

    test('synthesize with voice and instruct throws when model is not loaded', () {
      final mockBindings = MockTtsNativeBindings();
      final engine = TtsEngine(mockBindings);

      expect(
        () => engine.synthesize(
          'text',
          refWavPath: '/path/ref.wav',
          instruct: 'happy',
        ),
        throwsA(isA<TtsEngineException>()),
      );
    });
  });
}
