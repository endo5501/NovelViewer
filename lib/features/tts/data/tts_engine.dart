import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';

import 'tts_language.dart';
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

  @Deprecated('Use TtsLanguage.ja.languageId instead')
  static const int languageJapanese = TtsLanguage.defaultLanguageId;

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

  TtsSynthesisResult synthesize(String text) {
    _ensureLoaded();

    final textPtr = text.toNativeUtf8();
    try {
      final result = _bindings.synthesize(_ctx, textPtr);
      if (result != 0) {
        final error = _bindings.getError(_ctx).toDartString();
        throw TtsEngineException('Synthesis failed: $error');
      }
    } finally {
      calloc.free(textPtr);
    }

    return _extractAudio();
  }

  TtsSynthesisResult synthesizeWithVoice(String text, String refWavPath) {
    _ensureLoaded();

    final textPtr = text.toNativeUtf8();
    final wavPtr = refWavPath.toNativeUtf8();
    try {
      final result = _bindings.synthesizeWithVoice(_ctx, textPtr, wavPtr);
      if (result != 0) {
        final error = _bindings.getError(_ctx).toDartString();
        throw TtsEngineException('Synthesis with voice failed: $error');
      }
    } finally {
      calloc.free(textPtr);
      calloc.free(wavPtr);
    }

    return _extractAudio();
  }

  TtsSynthesisResult synthesizeWithVoiceCached(
    String text,
    String refWavPath, {
    required String embeddingCacheDir,
  }) {
    _ensureLoaded();

    final hash = _computeFileHash(refWavPath);
    final cacheDir = Directory(embeddingCacheDir);
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    final cachePath = '${cacheDir.path}/$hash.emb';
    final cacheFile = File(cachePath);

    final textPtr = text.toNativeUtf8();
    try {
      if (cacheFile.existsSync()) {
        try {
          if (_synthesizeFromCachedEmbedding(textPtr, cachePath)) {
            return _extractAudio();
          }
        } on TtsEngineException {
          // Synthesis with cached embedding failed — re-extract below
        }
        try {
          cacheFile.deleteSync();
        } on FileSystemException {
          // ignore
        }
      }

      // Cache miss: extract, save, synthesize
      _extractAndCacheEmbedding(textPtr, refWavPath, cachePath);
      return _extractAudio();
    } finally {
      calloc.free(textPtr);
    }
  }

  bool _synthesizeFromCachedEmbedding(
    Pointer<Utf8> textPtr,
    String cachePath,
  ) {
    final pathPtr = cachePath.toNativeUtf8();
    final outData = calloc<Pointer<Float>>();
    final outSize = calloc<Int32>();
    try {
      final loadResult =
          _bindings.loadSpeakerEmbedding(pathPtr, outData, outSize);
      if (loadResult != 0) return false;

      final embPtr = outData.value;
      final embSize = outSize.value;
      try {
        final result =
            _bindings.synthesizeWithEmbedding(_ctx, textPtr, embPtr, embSize);
        if (result != 0) {
          final error = _bindings.getError(_ctx).toDartString();
          throw TtsEngineException(
            'Synthesis with cached embedding failed: $error',
          );
        }
        return true;
      } finally {
        _bindings.freeSpeakerEmbedding(embPtr);
      }
    } finally {
      calloc.free(pathPtr);
      calloc.free(outData);
      calloc.free(outSize);
    }
  }

  void _extractAndCacheEmbedding(
    Pointer<Utf8> textPtr,
    String refWavPath,
    String cachePath,
  ) {
    final wavPtr = refWavPath.toNativeUtf8();
    final outData = calloc<Pointer<Float>>();
    final outSize = calloc<Int32>();
    try {
      final extractResult =
          _bindings.extractSpeakerEmbedding(_ctx, wavPtr, outData, outSize);
      if (extractResult != 0) {
        final error = _bindings.getError(_ctx).toDartString();
        throw TtsEngineException(
          'Speaker embedding extraction failed: $error',
        );
      }

      final embPtr = outData.value;
      final embSize = outSize.value;
      try {
        final cachePathPtr = cachePath.toNativeUtf8();
        try {
          final saveResult =
              _bindings.saveSpeakerEmbedding(cachePathPtr, embPtr, embSize);
          if (saveResult != 0) {
            try {
              File(cachePath).deleteSync();
            } on FileSystemException {
              // ignore
            }
          }
        } finally {
          calloc.free(cachePathPtr);
        }

        // Synthesize
        final result =
            _bindings.synthesizeWithEmbedding(_ctx, textPtr, embPtr, embSize);
        if (result != 0) {
          final error = _bindings.getError(_ctx).toDartString();
          throw TtsEngineException(
            'Synthesis with embedding failed: $error',
          );
        }
      } finally {
        _bindings.freeSpeakerEmbedding(embPtr);
      }
    } finally {
      calloc.free(wavPtr);
      calloc.free(outData);
      calloc.free(outSize);
    }
  }

  String _computeFileHash(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    return sha256.convert(bytes).toString();
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
