// ignore_for_file: prefer_function_declarations_over_variables

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/audiocpp_native_bindings.dart';
import 'package:novel_viewer/features/tts/data/irodori_tts_engine.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';

/// Mock bindings for testing IrodoriTtsEngine without loading the native
/// library.
class MockAudiocppNativeBindings extends AudiocppNativeBindings {
  MockAudiocppNativeBindings() : super(DynamicLibrary.process());

  Pointer<Void> _fakeCtx = nullptr;
  int _isLoadedResult = 0;

  void setFakeContext(Pointer<Void> ctx, {bool loaded = true}) {
    _fakeCtx = ctx;
    _isLoadedResult = loaded ? 1 : 0;
  }

  Pointer<Void>? lastInitAbortHandle;

  @override
  // ignore: overridden_fields
  late final Pointer<Void> Function(Pointer<Utf8>, int, Pointer<Void>) init =
      (Pointer<Utf8> modelDir, int nThreads, Pointer<Void> abortHandle) {
    lastInitAbortHandle = abortHandle;
    return _fakeCtx;
  };

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>) isLoaded =
      (Pointer<Void> ctx) => _isLoadedResult;

  bool freeCalled = false;

  @override
  // ignore: overridden_fields
  late final void Function(Pointer<Void>) free = (Pointer<Void> ctx) {
    freeCalled = true;
  };

  Pointer<Void>? lastAbortHandle;
  int abortCallCount = 0;
  Pointer<Void>? lastResetAbortHandle;
  int resetAbortCallCount = 0;

  @override
  // ignore: overridden_fields
  late final void Function(Pointer<Void>) abort = (Pointer<Void> handle) {
    lastAbortHandle = handle;
    abortCallCount++;
  };

  @override
  // ignore: overridden_fields
  late final void Function(Pointer<Void>) resetAbort = (Pointer<Void> handle) {
    lastResetAbortHandle = handle;
    resetAbortCallCount++;
  };

  String? lastText;
  Pointer<Utf8>? lastRefWavPathPtr;
  Pointer<Utf8>? lastCaptionPtr;
  double? lastSpeakerGuidanceScale;
  double? lastCaptionGuidanceScale;
  int? lastNumInferenceSteps;
  int synthesizeReturnCode = 0;

  @override
  // ignore: overridden_fields
  late final int Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    double,
    double,
    int,
  ) synthesize = (
    Pointer<Void> ctx,
    Pointer<Utf8> text,
    Pointer<Utf8> refWavPath,
    Pointer<Utf8> caption,
    double speakerGuidanceScale,
    double captionGuidanceScale,
    int numInferenceSteps,
  ) {
    lastText = text.toDartString();
    lastRefWavPathPtr = refWavPath;
    lastCaptionPtr = caption;
    lastSpeakerGuidanceScale = speakerGuidanceScale;
    lastCaptionGuidanceScale = captionGuidanceScale;
    lastNumInferenceSteps = numInferenceSteps;
    return synthesizeReturnCode;
  };

  Pointer<Float> audioBuffer = nullptr;
  int audioLength = 0;
  int sampleRateValue = 48000;

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

  String errorMessage = 'synthesis failed';

  @override
  // ignore: overridden_fields
  late final Pointer<Utf8> Function(Pointer<Void>) getError =
      (Pointer<Void> ctx) => errorMessage.toNativeUtf8();
}

void main() {
  group('IrodoriTtsEngine - loadModel', () {
    late MockAudiocppNativeBindings mockBindings;
    late IrodoriTtsEngine engine;

    setUp(() {
      mockBindings = MockAudiocppNativeBindings();
      engine = IrodoriTtsEngine(mockBindings);
    });

    test('isLoaded returns false before loading model', () {
      expect(engine.isLoaded, false);
    });

    test('loadModel sets isLoaded to true', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);

      engine.loadModel('/fake/model/dir');

      expect(engine.isLoaded, true);
    });

    test('loadModel wires the abort handle into native init', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      final fakeHandle = Pointer<Void>.fromAddress(0xABCD);
      mockBindings.setFakeContext(fakeCtx);

      engine.loadModel('/fake/model/dir', abortHandle: fakeHandle);

      expect(mockBindings.lastInitAbortHandle, fakeHandle);
    });

    test('loadModel throws when native init fails', () {
      mockBindings.setFakeContext(nullptr);

      expect(
        () => engine.loadModel('/fake/model/dir'),
        throwsA(isA<TtsEngineException>()),
      );
    });
  });

  group('IrodoriTtsEngine - synthesize', () {
    late MockAudiocppNativeBindings mockBindings;
    late IrodoriTtsEngine engine;

    setUp(() {
      mockBindings = MockAudiocppNativeBindings();
      engine = IrodoriTtsEngine(mockBindings);
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model/dir');
    });

    test('returns TtsSynthesisResult with 48kHz audio', () {
      final samples = Float32List.fromList([0.1, 0.2, -0.3]);
      final buf = calloc<Float>(samples.length);
      for (var i = 0; i < samples.length; i++) {
        buf[i] = samples[i];
      }
      mockBindings.audioBuffer = buf;
      mockBindings.audioLength = samples.length;
      mockBindings.sampleRateValue = 48000;

      try {
        final result = engine.synthesize(
          'こんにちは',
          speakerGuidanceScale: 5.0,
          captionGuidanceScale: 3.0,
          numInferenceSteps: 40,
        );

        expect(result.sampleRate, 48000);
        expect(result.audio, Float32List.fromList(samples));
      } finally {
        calloc.free(buf);
      }
    });

    test('passes text and guidance/steps parameters through to native call',
        () {
      engine.synthesize(
        'テスト',
        speakerGuidanceScale: 4.2,
        captionGuidanceScale: 2.1,
        numInferenceSteps: 25,
      );

      expect(mockBindings.lastText, 'テスト');
      expect(mockBindings.lastSpeakerGuidanceScale, 4.2);
      expect(mockBindings.lastCaptionGuidanceScale, 2.1);
      expect(mockBindings.lastNumInferenceSteps, 25);
    });

    test('null refWavPath and caption are passed as nullptr', () {
      engine.synthesize(
        'テスト',
        speakerGuidanceScale: 5.0,
        captionGuidanceScale: 3.0,
        numInferenceSteps: 40,
      );

      expect(mockBindings.lastRefWavPathPtr, nullptr);
      expect(mockBindings.lastCaptionPtr, nullptr);
    });

    test('empty refWavPath and caption are passed as nullptr', () {
      engine.synthesize(
        'テスト',
        refWavPath: '',
        caption: '',
        speakerGuidanceScale: 5.0,
        captionGuidanceScale: 3.0,
        numInferenceSteps: 40,
      );

      expect(mockBindings.lastRefWavPathPtr, nullptr);
      expect(mockBindings.lastCaptionPtr, nullptr);
    });

    test('non-null refWavPath and caption are forwarded as native strings',
        () {
      engine.synthesize(
        'テスト',
        refWavPath: '/voices/ref.wav',
        caption: '落ち着いた大人の女性の声',
        speakerGuidanceScale: 5.0,
        captionGuidanceScale: 3.0,
        numInferenceSteps: 40,
      );

      expect(mockBindings.lastRefWavPathPtr, isNot(nullptr));
      expect(mockBindings.lastRefWavPathPtr!.toDartString(), '/voices/ref.wav');
      expect(mockBindings.lastCaptionPtr, isNot(nullptr));
      expect(mockBindings.lastCaptionPtr!.toDartString(), '落ち着いた大人の女性の声');
    });

    test('throws TtsEngineException with native error message on failure',
        () {
      mockBindings.synthesizeReturnCode = 1;
      mockBindings.errorMessage = 'boom';

      expect(
        () => engine.synthesize(
          'テスト',
          speakerGuidanceScale: 5.0,
          captionGuidanceScale: 3.0,
          numInferenceSteps: 40,
        ),
        throwsA(isA<TtsEngineException>().having(
          (e) => e.message,
          'message',
          contains('boom'),
        )),
      );
    });
  });

  group('IrodoriTtsEngine - unloaded model', () {
    test('synthesize throws when model not loaded', () {
      final engine = IrodoriTtsEngine(MockAudiocppNativeBindings());

      expect(
        () => engine.synthesize(
          'テスト',
          speakerGuidanceScale: 5.0,
          captionGuidanceScale: 3.0,
          numInferenceSteps: 40,
        ),
        throwsA(isA<TtsEngineException>()),
      );
    });
  });

  group('IrodoriTtsEngine - abort', () {
    late MockAudiocppNativeBindings mockBindings;
    late IrodoriTtsEngine engine;

    setUp(() {
      mockBindings = MockAudiocppNativeBindings();
      engine = IrodoriTtsEngine(mockBindings);
    });

    test('abort calls native binding with the abort handle (not the context)',
        () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      final fakeHandle = Pointer<Void>.fromAddress(0xABCD);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model/dir', abortHandle: fakeHandle);

      engine.abort();

      expect(mockBindings.abortCallCount, 1);
      expect(mockBindings.lastAbortHandle, fakeHandle);
    });

    test('abort is no-op when no abort handle is wired', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model/dir');

      engine.abort();

      expect(mockBindings.abortCallCount, 0);
    });

    test('resetAbort calls native binding with the abort handle', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      final fakeHandle = Pointer<Void>.fromAddress(0xABCD);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model/dir', abortHandle: fakeHandle);

      engine.resetAbort();

      expect(mockBindings.resetAbortCallCount, 1);
      expect(mockBindings.lastResetAbortHandle, fakeHandle);
    });

    test('abort after dispose is safe and a no-op (handle reference dropped)',
        () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      final fakeHandle = Pointer<Void>.fromAddress(0xABCD);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model/dir', abortHandle: fakeHandle);

      engine.dispose();
      engine.abort();
      engine.resetAbort();

      expect(mockBindings.abortCallCount, 0);
      expect(mockBindings.resetAbortCallCount, 0);
    });
  });

  group('IrodoriTtsEngine - dispose', () {
    test('dispose frees native context and isLoaded becomes false', () {
      final mockBindings = MockAudiocppNativeBindings();
      final engine = IrodoriTtsEngine(mockBindings);
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model/dir');

      engine.dispose();

      expect(mockBindings.freeCalled, true);
      expect(engine.isLoaded, false);
    });
  });
}
