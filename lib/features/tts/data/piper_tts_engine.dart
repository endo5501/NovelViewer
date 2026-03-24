import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'piper_native_bindings.dart';
import 'tts_engine.dart';

class PiperTtsEngine {
  PiperTtsEngine(this._bindings);

  factory PiperTtsEngine.open() => PiperTtsEngine(PiperNativeBindings.open());

  final PiperNativeBindings _bindings;
  Pointer<Void> _ctx = nullptr;

  bool get isLoaded => _ctx != nullptr && _bindings.isLoaded(_ctx) != 0;

  void loadModel(String modelPath, {required String dicDir}) {
    if (_ctx != nullptr) {
      dispose();
    }

    final modelPathPtr = modelPath.toNativeUtf8();
    final dicDirPtr = dicDir.toNativeUtf8();
    try {
      _ctx = _bindings.init(modelPathPtr, dicDirPtr);
    } finally {
      calloc.free(modelPathPtr);
      calloc.free(dicDirPtr);
    }

    if (_ctx == nullptr || !isLoaded) {
      final error = _ctx != nullptr
          ? _bindings.getError(_ctx).toDartString()
          : 'Failed to create context';
      throw TtsEngineException('Failed to load Piper model: $error');
    }
  }

  void setLengthScale(double value) {
    _ensureLoaded();
    _bindings.setLengthScale(_ctx, value);
  }

  void setNoiseScale(double value) {
    _ensureLoaded();
    _bindings.setNoiseScale(_ctx, value);
  }

  void setNoiseW(double value) {
    _ensureLoaded();
    _bindings.setNoiseW(_ctx, value);
  }

  TtsSynthesisResult synthesize(String text) {
    _ensureLoaded();

    final textPtr = text.toNativeUtf8();
    try {
      final result = _bindings.synthesize(_ctx, textPtr);
      if (result != 0) {
        final error = _bindings.getError(_ctx).toDartString();
        throw TtsEngineException('Piper synthesis failed: $error');
      }
    } finally {
      calloc.free(textPtr);
    }

    return _extractAudio();
  }

  void dispose() {
    if (_ctx != nullptr) {
      _bindings.free(_ctx);
      _ctx = nullptr;
    }
  }

  void _ensureLoaded() {
    if (!isLoaded) {
      throw const TtsEngineException('Piper model not loaded');
    }
  }

  TtsSynthesisResult _extractAudio() {
    final length = _bindings.getAudioLength(_ctx);
    final sampleRate = _bindings.getSampleRate(_ctx);
    final audioPtr = _bindings.getAudio(_ctx);

    if (audioPtr == nullptr || length <= 0) {
      throw const TtsEngineException('No audio data generated');
    }

    final audio = Float32List.fromList(audioPtr.asTypedList(length));

    return TtsSynthesisResult(audio: audio, sampleRate: sampleRate);
  }
}
