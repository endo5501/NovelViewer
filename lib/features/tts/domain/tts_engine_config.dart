import 'package:flutter_riverpod/flutter_riverpod.dart';
// `ProviderListenable` is the upper bound that both `WidgetRef.read` and
// `ProviderContainer.read` accept, but it is not re-exported by the public
// flutter_riverpod entry point. Pulling it from `src/internals.dart` lets
// the [ProviderReader] typedef precisely match those signatures.
import 'package:flutter_riverpod/src/internals.dart' show ProviderListenable;

import '../data/tts_engine_type.dart';
import '../providers/tts_settings_providers.dart';

/// Reads a provider's current value without subscribing.
///
/// Compatible with `WidgetRef.read`, `Ref.read`, and `ProviderContainer.read`.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

const int _qwen3SampleRate = 24000;
const int _piperSampleRate = 22050;

/// Engine-specific configuration for TTS synthesis.
///
/// Sealed so the type system enforces an exhaustive switch over the supported
/// engines. Each subclass carries only the fields that the corresponding
/// native engine consumes — adding a Piper-only knob to Qwen3 (or vice versa)
/// is a compile-time error.
sealed class TtsEngineConfig {
  const TtsEngineConfig({
    required this.modelDir,
    required this.sampleRate,
  });

  /// Filesystem location of the engine's model. For Qwen3 this is a directory
  /// containing the model files; for Piper this is the absolute path to the
  /// `.onnx` model file.
  final String modelDir;

  /// PCM sample rate produced by the engine (Hz).
  final int sampleRate;

  /// Build the engine config for [type] by reading the relevant Riverpod
  /// providers via [read].
  ///
  /// All reads use `read` (not `watch`), so callers do not subscribe to
  /// rebuilds.
  static TtsEngineConfig resolveFromReader(
    ProviderReader read,
    TtsEngineType type,
  ) {
    return switch (type) {
      TtsEngineType.qwen3 => _resolveQwen3(read),
      TtsEngineType.piper => _resolvePiper(read),
    };
  }

  /// Convenience wrapper around [resolveFromReader] for widget code.
  static TtsEngineConfig resolveFromRef(WidgetRef ref, TtsEngineType type) {
    return resolveFromReader(<T>(p) => ref.read(p), type);
  }
}

class Qwen3EngineConfig extends TtsEngineConfig {
  const Qwen3EngineConfig({
    required super.modelDir,
    required super.sampleRate,
    required this.languageId,
    this.refWavPath,
    this.embeddingCacheDir,
  });

  /// IETF / Qwen3 language code (e.g. 2058 for ja).
  final int languageId;

  /// Absolute path to a reference WAV used for voice cloning. `null` disables
  /// voice cloning and uses the model's default voice.
  final String? refWavPath;

  /// Directory under which speaker-embedding caches are stored. `null`
  /// disables embedding caching.
  final String? embeddingCacheDir;
}

class PiperEngineConfig extends TtsEngineConfig {
  const PiperEngineConfig({
    required super.modelDir,
    required super.sampleRate,
    required this.dicDir,
    required this.lengthScale,
    required this.noiseScale,
    required this.noiseW,
  });

  /// Absolute path to the OpenJTalk dictionary directory used by Piper.
  final String dicDir;

  /// Phoneme duration scaling — higher values yield slower speech.
  final double lengthScale;

  /// Synthesis noise scale.
  final double noiseScale;

  /// Synthesis noise-W scale (controls noise duration).
  final double noiseW;
}

Qwen3EngineConfig _resolveQwen3(ProviderReader read) {
  final modelDir = read(ttsModelDirProvider);
  final language = read(ttsLanguageProvider);
  final refWavFileName = read(ttsRefWavPathProvider);
  final voiceService = read(voiceReferenceServiceProvider);
  final refWavPath = refWavFileName.isNotEmpty && voiceService != null
      ? voiceService.resolveVoiceFilePath(refWavFileName)
      : null;
  return Qwen3EngineConfig(
    modelDir: modelDir,
    sampleRate: _qwen3SampleRate,
    languageId: language.languageId,
    refWavPath: refWavPath,
    embeddingCacheDir: read(embeddingCacheDirProvider),
  );
}

PiperEngineConfig _resolvePiper(ProviderReader read) {
  final piperDir = read(piperModelDirProvider);
  final modelName = read(piperModelNameProvider);
  return PiperEngineConfig(
    modelDir: '$piperDir/$modelName.onnx',
    sampleRate: _piperSampleRate,
    dicDir: read(piperDicDirProvider),
    lengthScale: read(piperLengthScaleProvider),
    noiseScale: read(piperNoiseScaleProvider),
    noiseW: read(piperNoiseWProvider),
  );
}
