import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'tts_native_bindings.dart';

class TtsSynthesisResult {
  const TtsSynthesisResult({
    required this.audio,
    required this.sampleRate,
  });

  final Float32List audio;
  final int sampleRate;
}

class TtsEngineException implements Exception {
  const TtsEngineException(this.message);
  final String message;

  @override
  String toString() => 'TtsEngineException: $message';
}

class TtsEngine {
  TtsEngine(this._bindings);

  factory TtsEngine.open() => TtsEngine(TtsNativeBindings.open());

  static const int languageJapanese = 2058;

  final TtsNativeBindings _bindings;
  Pointer<Void> _ctx = nullptr;

  bool get isLoaded => _ctx != nullptr && _bindings.isLoaded(_ctx) != 0;

  void setLanguage(int languageId) {
    _ensureLoaded();
    _bindings.setLanguage(_ctx, languageId);
  }

  void loadModel(String modelDir, {int nThreads = 4}) {
    if (_ctx != nullptr) {
      dispose();
    }

    final modelDirPtr = modelDir.toNativeUtf8();
    try {
      _ctx = _bindings.init(modelDirPtr, nThreads);
    } finally {
      calloc.free(modelDirPtr);
    }

    if (_ctx == nullptr) {
      throw const TtsEngineException('Failed to load TTS model');
    }
  }

  TtsSynthesisResult synthesize(String text, {String? refWavPath, String? instruct}) {
    _ensureLoaded();

    // Normalize empty instruct to null
    final effectiveInstruct = (instruct != null && instruct.isNotEmpty) ? instruct : null;

    final textPtr = text.toNativeUtf8();
    final wavPtr = refWavPath?.toNativeUtf8();
    final instructPtr = effectiveInstruct?.toNativeUtf8();
    try {
      final int result;
      if (wavPtr != null && instructPtr != null) {
        result = _bindings.synthesizeWithVoiceAndInstruct(
            _ctx, textPtr, wavPtr, instructPtr);
      } else if (wavPtr != null) {
        result = _bindings.synthesizeWithVoice(_ctx, textPtr, wavPtr);
      } else if (instructPtr != null) {
        result = _bindings.synthesizeWithInstruct(_ctx, textPtr, instructPtr);
      } else {
        result = _bindings.synthesize(_ctx, textPtr);
      }
      if (result != 0) {
        final error = _bindings.getError(_ctx).toDartString();
        throw TtsEngineException('Synthesis failed: $error');
      }
    } finally {
      calloc.free(textPtr);
      if (wavPtr != null) calloc.free(wavPtr);
      if (instructPtr != null) calloc.free(instructPtr);
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
      throw const TtsEngineException('Model not loaded');
    }
  }

  TtsSynthesisResult _extractAudio() {
    final length = _bindings.getAudioLength(_ctx);
    final sampleRate = _bindings.getSampleRate(_ctx);
    final audioPtr = _bindings.getAudio(_ctx);

    if (audioPtr == nullptr || length <= 0) {
      throw const TtsEngineException('No audio data generated');
    }

    // Copy the audio data from native memory to a Dart-owned Float32List
    final audio = Float32List(length);
    for (var i = 0; i < length; i++) {
      audio[i] = audioPtr[i];
    }

    return TtsSynthesisResult(audio: audio, sampleRate: sampleRate);
  }
}
