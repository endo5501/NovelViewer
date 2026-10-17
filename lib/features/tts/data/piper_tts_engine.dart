import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
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

  /// Length of the silence returned for text with nothing to pronounce; the
  /// same as upstream's default gap between sentences.
  static const _unspeakableSilenceSeconds = 0.2;

  final PiperNativeBindings _bindings;
  Pointer<Void> _engine = nullptr;

  // Upstream's C API has no per-engine parameter setters: options travel with
  // each synthesize call, so the engine keeps them. null = upstream default.
  double? _lengthScale;
  double? _noiseScale;
  double? _noiseW;
  int _languageId = -1;

  /// Phonemes the model has ids for; null when the config could not be read,
  /// in which case every text goes to native synthesis.
  Set<String>? _knownPhonemes;

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

    final modelConfig = _readModelConfig('$modelPath.json');
    final configPath = _japaneseConfigPath(modelPath, modelConfig);

    final config = calloc<PiperPlusConfig>();
    final outEngine = calloc<Pointer<Void>>();
    final modelPathPtr = modelPath.toNativeUtf8();
    final configPathPtr = configPath.toNativeUtf8();
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

    final phonemeIdMap = modelConfig?['phoneme_id_map'];
    _knownPhonemes = phonemeIdMap is Map
        ? phonemeIdMap.keys.cast<String>().toSet()
        : null;
  }

  static Map<String, dynamic>? _readModelConfig(String path) {
    try {
      final decoded = jsonDecode(File(path).readAsStringSync());
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      // Leave reporting to the native loader, which reads the same file.
      return null;
    }
  }

  /// Upstream's script detector reads kana-less CJK ideographs as Chinese
  /// whenever the model also knows `ja` (language_detector.cpp), ignoring the
  /// requested language. With no pinyin dictionary bundled, a sentence such as
  /// 「多分。」 then has nothing to pronounce. The detector draws its candidates
  /// from `language_id_map`, so the native engine gets a copy of the config
  /// without `zh`; the remaining ids are untouched, so `lid` values match the
  /// model. The downloaded config stays as fetched.
  static String _japaneseConfigPath(
    String modelPath,
    Map<String, dynamic>? modelConfig,
  ) {
    final downloaded = '$modelPath.json';
    final languages = modelConfig?['language_id_map'];
    if (languages is! Map ||
        !languages.containsKey('ja') ||
        !languages.containsKey('zh')) {
      return downloaded;
    }
    final japaneseLanguages = Map<String, dynamic>.of(
      languages.cast<String, dynamic>(),
    )..remove('zh');
    final derived = Map<String, dynamic>.of(modelConfig!)
      ..['language_id_map'] = japaneseLanguages;
    final derivedPath = '$modelPath.ja.json';
    File(derivedPath).writeAsStringSync(jsonEncode(derived));
    return derivedPath;
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

    // Upstream v2 runs inference even on an empty id sequence and fails with
    // "Invalid input shape: {0}", which would stop playback. v1.8 produced
    // silence for such text, so keep that.
    if (!_hasSpeakablePhoneme(text)) {
      final sampleRate = _bindings.sampleRate(_engine);
      return TtsSynthesisResult(
        audio: Float32List((sampleRate * _unspeakableSilenceSeconds).round()),
        sampleRate: sampleRate,
      );
    }

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

  /// Whether [text] phonemizes to at least one phoneme the model has an id
  /// for — the same lookup native synthesis applies before inference.
  bool _hasSpeakablePhoneme(String text) {
    final known = _knownPhonemes;
    if (known == null) return true;

    final result = calloc<PiperPlusPhonemeResult>();
    final textPtr = text.toNativeUtf8();
    final languagePtr = _language.toNativeUtf8();
    try {
      final status = _bindings.phonemize(_engine, textPtr, languagePtr, result);
      // Let synthesis report a phonemizer failure with its own message.
      if (status != piperPlusOk || result.ref.phonemes == nullptr) return true;
      // Borrowed until the next call on this engine: read it now.
      final phonemes = result.ref.phonemes.toDartString();
      return phonemes.split(' ').any(known.contains);
    } finally {
      calloc.free(languagePtr);
      calloc.free(textPtr);
      calloc.free(result);
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
    _knownPhonemes = null;
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
