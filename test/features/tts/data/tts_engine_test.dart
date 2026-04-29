// ignore_for_file: prefer_function_declarations_over_variables

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';
import 'package:novel_viewer/features/tts/data/tts_language.dart';
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

  Pointer<Void>? lastAbortCtx;
  int abortCallCount = 0;
  Pointer<Void>? lastResetAbortCtx;
  int resetAbortCallCount = 0;

  @override
  // ignore: overridden_fields
  late final void Function(Pointer<Void>) abort = (Pointer<Void> ctx) {
    lastAbortCtx = ctx;
    abortCallCount++;
  };

  @override
  // ignore: overridden_fields
  late final void Function(Pointer<Void>) resetAbort = (Pointer<Void> ctx) {
    lastResetAbortCtx = ctx;
    resetAbortCallCount++;
  };

  Pointer<Float> audioBuffer = nullptr;
  int audioLength = 0;
  int sampleRateValue = 0;
  int synthesizeReturnCode = 0;

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>, Pointer<Utf8>, int) synthesize =
      (Pointer<Void> ctx, Pointer<Utf8> text, int maxTokens) =>
          synthesizeReturnCode;

  @override
  // ignore: overridden_fields
  late final Pointer<Float> Function(Pointer<Void>) getAudio =
      (Pointer<Void> ctx) => audioBuffer;

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>) getAudioLength =
      (Pointer<Void> ctx) => audioLength;

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>) getSampleRate =
      (Pointer<Void> ctx) => sampleRateValue;
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

    test('TtsLanguage.ja.languageId equals 2058', () {
      expect(TtsLanguage.ja.languageId, 2058);
    });
  });

  group('TtsEngine - synthesize / audio extraction', () {
    late MockTtsNativeBindings mockBindings;
    late TtsEngine engine;

    setUp(() {
      mockBindings = MockTtsNativeBindings();
      engine = TtsEngine(mockBindings);
    });

    test(
        'synthesize copies the native audio buffer into a Float32List that is '
        'byte-equivalent to Float32List.fromList of the same samples', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);

      const samples = <double>[
        0.0,
        0.1,
        -0.1,
        0.5,
        -0.5,
        1.0,
        -1.0,
        0.123456,
      ];
      final buf = calloc<Float>(samples.length);
      for (var i = 0; i < samples.length; i++) {
        buf[i] = samples[i];
      }

      mockBindings.audioBuffer = buf;
      mockBindings.audioLength = samples.length;
      mockBindings.sampleRateValue = 24000;

      try {
        engine.loadModel('/fake/model/dir');
        final result = engine.synthesize('hello');

        expect(result.sampleRate, 24000);
        expect(result.audio.length, samples.length);

        final expected = Float32List.fromList(samples);
        expect(result.audio, expected);

        // Byte-level equivalence guards against representation drift when the
        // implementation switches between per-element copy and asTypedList.
        expect(result.audio.buffer.asUint8List(),
            expected.buffer.asUint8List());
      } finally {
        calloc.free(buf);
      }
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

      engine.setLanguage(TtsLanguage.ja.languageId);

      expect(mockBindings.lastSetLanguageId, 2058);
    });

    test('setLanguage throws when model is not loaded', () {
      expect(
        () => engine.setLanguage(TtsLanguage.ja.languageId),
        throwsA(isA<TtsEngineException>()),
      );
    });
  });

  group('TtsEngine - abort', () {
    late MockTtsNativeBindings mockBindings;
    late TtsEngine engine;

    setUp(() {
      mockBindings = MockTtsNativeBindings();
      engine = TtsEngine(mockBindings);
    });

    test('abort calls native binding with context pointer', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model/dir');

      engine.abort();

      expect(mockBindings.abortCallCount, 1);
      expect(mockBindings.lastAbortCtx, fakeCtx);
    });

    test('abort is no-op when model is not loaded', () {
      engine.abort();

      expect(mockBindings.abortCallCount, 0);
    });

    test('resetAbort calls native binding with context pointer', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model/dir');

      engine.resetAbort();

      expect(mockBindings.resetAbortCallCount, 1);
      expect(mockBindings.lastResetAbortCtx, fakeCtx);
    });

    test('resetAbort is no-op when model is not loaded', () {
      engine.resetAbort();

      expect(mockBindings.resetAbortCallCount, 0);
    });

    test('ctxAddress returns pointer address when model is loaded', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model/dir');

      expect(engine.ctxAddress, 0x1234);
    });

    test('ctxAddress returns null when model is not loaded', () {
      expect(engine.ctxAddress, isNull);
    });
  });

  group('TtsEngine - calculateMaxAudioTokens', () {
    test('short text (10 chars) returns proportional limit', () {
      expect(TtsEngine.calculateMaxAudioTokens(10), 200);
    });

    test('medium text (50 chars) returns proportional limit', () {
      expect(TtsEngine.calculateMaxAudioTokens(50), 800);
    });

    test('long text (200 chars) is capped at 2048', () {
      expect(TtsEngine.calculateMaxAudioTokens(200), 2048);
    });

    test('very short text (1 char) has minimum floor', () {
      expect(TtsEngine.calculateMaxAudioTokens(1), 65);
    });

    test('zero length text returns minimum', () {
      expect(TtsEngine.calculateMaxAudioTokens(0), 50);
    });
  });
}
