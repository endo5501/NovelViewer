import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'piper_native_bindings.dart';
import 'tts_engine.dart';

class PiperTtsEngine {
  PiperTtsEngine(this._bindings);

  factory PiperTtsEngine.open() => PiperTtsEngine(PiperNativeBindings.open());

  /// Language requested for every synthesis. v1.8 always fed the model's
  /// language id 0 (`ja`); upstream v2 defaults to auto-detection instead, so
  /// the id is resolved explicitly to keep that behavior.
  static const _language = 'ja';

  final PiperNativeBindings _bindings;
  Pointer<Void> _engine = nullptr;

  // Upstream's C API has no per-engine parameter setters: options travel with
  // each synthesize call, so the engine keeps them. null = upstream default.
  double? _lengthScale;
  double? _noiseScale;
  double? _noiseW;
  int _languageId = -1;

  bool get isLoaded => _engine != nullptr;

  void loadModel(String modelPath, {required String dicDir}) {
    if (_engine != nullptr) {
      dispose();
    }

    final apiVersion = _bindings.apiVersion();
    if (apiVersion != piperPlusApiVersion) {
      throw TtsEngineException(
        'Unsupported piper-plus C API version: expected '
        '$piperPlusApiVersion, got $apiVersion',
      );
    }

    final config = calloc<PiperPlusConfig>();
    final outEngine = calloc<Pointer<Void>>();
    final modelPathPtr = modelPath.toNativeUtf8();
    final configPathPtr = '$modelPath.json'.toNativeUtf8();
    final dicDirPtr = dicDir.toNativeUtf8();
    try {
      // calloc zero-fills, which the C API requires of the reserved fields.
      config.ref
        ..modelPath = modelPathPtr
        ..configPath = configPathPtr
        ..dictDir = dicDirPtr;

      final status = _bindings.create(config, outEngine);
      if (status != piperPlusOk || outEngine.value == nullptr) {
        throw TtsEngineException('Failed to load Piper model: ${_lastError()}');
      }
      _engine = outEngine.value;
    } finally {
      calloc.free(dicDirPtr);
      calloc.free(configPathPtr);
      calloc.free(modelPathPtr);
      calloc.free(outEngine);
      calloc.free(config);
    }

    final languagePtr = _language.toNativeUtf8();
    try {
      _languageId = _bindings.languageId(_engine, languagePtr);
    } finally {
      calloc.free(languagePtr);
    }
  }

  void setLengthScale(double value) {
    _ensureLoaded();
    _lengthScale = value;
  }

  void setNoiseScale(double value) {
    _ensureLoaded();
    _noiseScale = value;
  }

  void setNoiseW(double value) {
    _ensureLoaded();
    _noiseW = value;
  }

  TtsSynthesisResult synthesize(String text) {
    _ensureLoaded();

    final opts = calloc<PiperPlusSynthOptions>();
    final outSamples = calloc<Pointer<Float>>();
    final outNumSamples = calloc<Int32>();
    final outSampleRate = calloc<Int32>();
    final textPtr = text.toNativeUtf8();
    try {
      // Start from upstream's defaults so the reserved fields and any option
      // the app does not set keep the values the C API expects.
      opts.ref = _bindings.defaultOptions();
      opts.ref.languageId = _languageId;
      if (_lengthScale != null) opts.ref.lengthScale = _lengthScale!;
      if (_noiseScale != null) opts.ref.noiseScale = _noiseScale!;
      if (_noiseW != null) opts.ref.noiseW = _noiseW!;

      final status = _bindings.synthesize(
        _engine,
        textPtr,
        opts,
        outSamples,
        outNumSamples,
        outSampleRate,
      );
      final samples = outSamples.value;
      try {
        if (status != piperPlusOk) {
          throw TtsEngineException('Piper synthesis failed: ${_lastError()}');
        }
        final length = outNumSamples.value;
        if (samples == nullptr || length <= 0) {
          throw const TtsEngineException('No audio data generated');
        }
        return TtsSynthesisResult(
          audio: Float32List.fromList(samples.asTypedList(length)),
          sampleRate: outSampleRate.value,
        );
      } finally {
        // The buffer is caller-owned; release it whatever the outcome.
        if (samples != nullptr) {
          _bindings.freeAudio(samples);
        }
      }
    } finally {
      calloc.free(textPtr);
      calloc.free(outSampleRate);
      calloc.free(outNumSamples);
      calloc.free(outSamples);
      calloc.free(opts);
    }
  }

  void dispose() {
    if (_engine != nullptr) {
      _bindings.free(_engine);
      _engine = nullptr;
    }
    _lengthScale = null;
    _noiseScale = null;
    _noiseW = null;
    _languageId = -1;
  }

  void _ensureLoaded() {
    if (!isLoaded) {
      throw const TtsEngineException('Piper model not loaded');
    }
  }

  /// Must run synchronously right after the failing call: the native message
  /// is stored thread-locally.
  String _lastError() {
    final ptr = _bindings.getLastError();
    return ptr == nullptr ? 'unknown error' : ptr.toDartString();
  }
}
