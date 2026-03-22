// ignore_for_file: prefer_function_declarations_over_variables

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/piper_native_bindings.dart';
import 'package:novel_viewer/features/tts/data/piper_tts_engine.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';

/// Mock bindings for testing PiperTtsEngine without loading native library.
class MockPiperNativeBindings extends PiperNativeBindings {
  MockPiperNativeBindings() : super(DynamicLibrary.process());

  Pointer<Void> _fakeCtx = nullptr;
  int _isLoadedResult = 0;
  double? lastLengthScale;
  double? lastNoiseScale;
  double? lastNoiseW;
  bool synthesizeCalled = false;

  // Fake audio data for synthesis
  late final Pointer<Float> _fakeAudioPtr;
  int _fakeAudioLength = 0;
  int _fakeSampleRate = 22050;

  void setFakeContext(Pointer<Void> ctx, {bool loaded = true}) {
    _fakeCtx = ctx;
    _isLoadedResult = loaded ? 1 : 0;
  }

  void setFakeAudio(Float32List audio, {int sampleRate = 22050}) {
    _fakeAudioPtr = calloc<Float>(audio.length);
    for (var i = 0; i < audio.length; i++) {
      _fakeAudioPtr[i] = audio[i];
    }
    _fakeAudioLength = audio.length;
    _fakeSampleRate = sampleRate;
  }

  @override
  // ignore: overridden_fields
  late final Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>) init =
      (Pointer<Utf8> modelPath, Pointer<Utf8> dicDir) => _fakeCtx;

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>) isLoaded =
      (Pointer<Void> ctx) => _isLoadedResult;

  @override
  // ignore: overridden_fields
  late final void Function(Pointer<Void>) free = (Pointer<Void> ctx) {};

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>, Pointer<Utf8>) synthesize =
      (Pointer<Void> ctx, Pointer<Utf8> text) {
    synthesizeCalled = true;
    return 0;
  };

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>, double) setLengthScale =
      (Pointer<Void> ctx, double value) {
    lastLengthScale = value;
    return 0;
  };

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>, double) setNoiseScale =
      (Pointer<Void> ctx, double value) {
    lastNoiseScale = value;
    return 0;
  };

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>, double) setNoiseW =
      (Pointer<Void> ctx, double value) {
    lastNoiseW = value;
    return 0;
  };

  @override
  // ignore: overridden_fields
  late final Pointer<Float> Function(Pointer<Void>) getAudio =
      (Pointer<Void> ctx) => _fakeAudioPtr;

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>) getAudioLength =
      (Pointer<Void> ctx) => _fakeAudioLength;

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>) getSampleRate =
      (Pointer<Void> ctx) => _fakeSampleRate;

  @override
  // ignore: overridden_fields
  late final Pointer<Utf8> Function(Pointer<Void>) getError =
      (Pointer<Void> ctx) => ''.toNativeUtf8();
}

void main() {
  group('PiperTtsEngine', () {
    late MockPiperNativeBindings mockBindings;
    late PiperTtsEngine engine;

    setUp(() {
      mockBindings = MockPiperNativeBindings();
      engine = PiperTtsEngine(mockBindings);
    });

    test('isLoaded returns false before loading model', () {
      expect(engine.isLoaded, false);
    });

    test('loadModel sets isLoaded to true', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model.onnx', dicDir: '/fake/dic');
      expect(engine.isLoaded, true);
    });

    test('loadModel throws when native init fails', () {
      mockBindings.setFakeContext(nullptr);
      expect(
        () => engine.loadModel('/fake/model.onnx', dicDir: '/fake/dic'),
        throwsA(isA<TtsEngineException>()),
      );
    });

    test('synthesize returns TtsSynthesisResult', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      mockBindings.setFakeAudio(
        Float32List.fromList([0.1, 0.2, -0.3]),
        sampleRate: 22050,
      );
      engine.loadModel('/fake/model.onnx', dicDir: '/fake/dic');

      final result = engine.synthesize('テスト');

      expect(result, isA<TtsSynthesisResult>());
      expect(result.audio.length, 3);
      expect(result.sampleRate, 22050);
      expect(mockBindings.synthesizeCalled, true);
    });

    test('synthesize throws when model not loaded', () {
      expect(
        () => engine.synthesize('テスト'),
        throwsA(isA<TtsEngineException>()),
      );
    });

    test('setLengthScale calls native binding', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model.onnx', dicDir: '/fake/dic');

      engine.setLengthScale(0.8);
      expect(mockBindings.lastLengthScale, 0.8);
    });

    test('setNoiseScale calls native binding', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model.onnx', dicDir: '/fake/dic');

      engine.setNoiseScale(0.5);
      expect(mockBindings.lastNoiseScale, 0.5);
    });

    test('setNoiseW calls native binding', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model.onnx', dicDir: '/fake/dic');

      engine.setNoiseW(0.6);
      expect(mockBindings.lastNoiseW, 0.6);
    });

    test('setLengthScale throws when model not loaded', () {
      expect(
        () => engine.setLengthScale(1.0),
        throwsA(isA<TtsEngineException>()),
      );
    });

    test('dispose frees native context', () {
      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model.onnx', dicDir: '/fake/dic');

      engine.dispose();
      expect(engine.isLoaded, false);
    });
  });
}
