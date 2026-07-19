import 'package:flutter_riverpod/flutter_riverpod.dart';
// `ProviderListenable` is the upper bound that both `WidgetRef.read` and
// `ProviderContainer.read` accept. It lives in the auxiliary `misc.dart`
// entry point rather than the main flutter_riverpod export, so import it
// from there to keep [ProviderReader] matching those signatures.
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:path/path.dart' as p;

import '../data/tts_engine_type.dart';
import '../providers/tts_settings_providers.dart';

/// Reads a provider's current value without subscribing.
///
/// Compatible with `WidgetRef.read`, `Ref.read`, and `ProviderContainer.read`.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

const int _qwen3SampleRate = 24000;
const int _piperSampleRate = 22050;
const int _irodoriSampleRate = 48000;

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

  /// Cache key for the underlying isolate's `loadModel`. Two configs that
  /// share the same key produce the same loaded model — useful so Qwen3
  /// regenerate calls that swap only `refWavPath` (synthesis-time, not
  /// load-time) don't trigger a needless model reload.
  Object get modelLoadKey;

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
      TtsEngineType.irodori => _resolveIrodori(read),
    };
  }

  /// Convenience wrapper around [resolveFromReader] for widget code.
  static TtsEngineConfig resolveFromRef(WidgetRef ref, TtsEngineType type) {
    return resolveFromReader(<T>(p) => ref.read(p), type);
  }

  /// Maps a segment [memo] to the synthesis-time `caption` for [config].
  ///
  /// Only Irodori consumes the memo as a caption (design D8); for Qwen3/Piper
  /// this always returns `null` so the memo never influences synthesis. A
  /// `null` or empty memo yields `null` (clone-only / plain synthesis).
  /// Centralised here so every synthesis call site applies the same rule.
  static String? captionFromMemo(TtsEngineConfig config, String? memo) {
    if (config is! IrodoriEngineConfig) return null;
    if (memo == null || memo.isEmpty) return null;
    return memo;
  }

  /// Fallback reference WAV path for synthesis-time voice cloning, used when
  /// a segment/episode specifies no override of its own.
  ///
  /// Qwen3 and Irodori share the voice reference library (design D9) and
  /// both expose a synthesis-time `refWavPath`, so this returns it for
  /// either. Piper has no voice cloning, so this is always `null` for
  /// [PiperEngineConfig]. Centralised here so every call site that resolves
  /// a fallback ref WAV (edit controller, streaming controller) uses the
  /// same rule instead of repeating the switch.
  String? get synthesisFallbackRefWavPath => switch (this) {
        Qwen3EngineConfig(:final refWavPath) => refWavPath,
        IrodoriEngineConfig(:final refWavPath) => refWavPath,
        PiperEngineConfig() => null,
      };

  /// Irodori-only synthesis-time parameters (speaker/caption guidance scales
  /// and diffusion step count), bundled as a single record so call sites can
  /// extract all three with one type check instead of three separate
  /// `config is IrodoriEngineConfig ? config.x : null` expressions.
  ///
  /// `null` for qwen3/piper, which do not have these parameters.
  ({
    double speakerGuidanceScale,
    double captionGuidanceScale,
    int numInferenceSteps,
  })? get irodoriSynthesisParams => switch (this) {
        IrodoriEngineConfig(
          :final speakerGuidanceScale,
          :final captionGuidanceScale,
          :final numInferenceSteps,
        ) =>
          (
            speakerGuidanceScale: speakerGuidanceScale,
            captionGuidanceScale: captionGuidanceScale,
            numInferenceSteps: numInferenceSteps,
          ),
        Qwen3EngineConfig() => null,
        PiperEngineConfig() => null,
      };
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

  /// Returns a copy with [refWavPath] overridden. Used by the edit dialog
  /// to swap the global ref WAV for a per-segment one without rebuilding
  /// every field by hand.
  Qwen3EngineConfig copyWithRefWavPath(String? refWavPath) =>
      Qwen3EngineConfig(
        modelDir: modelDir,
        sampleRate: sampleRate,
        languageId: languageId,
        refWavPath: refWavPath,
        embeddingCacheDir: embeddingCacheDir,
      );

  // refWavPath is synthesis-time (passed per-call), so it is intentionally
  // omitted from the load key — swapping it must not reload the model.
  @override
  Object get modelLoadKey =>
      (TtsEngineType.qwen3, modelDir, languageId, embeddingCacheDir);
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

  @override
  Object get modelLoadKey => (
        TtsEngineType.piper,
        modelDir,
        dicDir,
        lengthScale,
        noiseScale,
        noiseW,
      );
}

class IrodoriEngineConfig extends TtsEngineConfig {
  const IrodoriEngineConfig({
    required super.modelDir,
    required super.sampleRate,
    this.refWavPath,
    required this.speakerGuidanceScale,
    required this.captionGuidanceScale,
    required this.numInferenceSteps,
  });

  /// Absolute path to a reference WAV used for voice cloning (synthesis-time,
  /// shares the same voice library as Qwen3). `null` disables cloning.
  final String? refWavPath;

  /// Balances adherence to the reference voice vs. the caption (design D8).
  final double speakerGuidanceScale;

  /// Balances adherence to the caption vs. the reference voice.
  final double captionGuidanceScale;

  /// Number of RF diffusion sampling steps.
  final int numInferenceSteps;

  /// Returns a copy with [refWavPath] overridden. Mirrors
  /// [Qwen3EngineConfig.copyWithRefWavPath] for per-segment ref WAV swaps in
  /// the edit dialog.
  IrodoriEngineConfig copyWithRefWavPath(String? refWavPath) =>
      IrodoriEngineConfig(
        modelDir: modelDir,
        sampleRate: sampleRate,
        refWavPath: refWavPath,
        speakerGuidanceScale: speakerGuidanceScale,
        captionGuidanceScale: captionGuidanceScale,
        numInferenceSteps: numInferenceSteps,
      );

  // refWavPath / guidance scales / steps are synthesis-time parameters
  // (passed per-call, like caption), so they are intentionally omitted from
  // the load key — changing them must not reload the model (design D8).
  @override
  Object get modelLoadKey => (TtsEngineType.irodori, modelDir);
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
    modelDir: p.join(piperDir, '$modelName.onnx'),
    sampleRate: _piperSampleRate,
    dicDir: read(piperDicDirProvider),
    lengthScale: read(piperLengthScaleProvider),
    noiseScale: read(piperNoiseScaleProvider),
    noiseW: read(piperNoiseWProvider),
  );
}

IrodoriEngineConfig _resolveIrodori(ProviderReader read) {
  final modelDir = read(irodoriModelDirProvider);
  // Shared voice reference library — same provider/service as Qwen3 (D9).
  final refWavFileName = read(ttsRefWavPathProvider);
  final voiceService = read(voiceReferenceServiceProvider);
  final refWavPath = refWavFileName.isNotEmpty && voiceService != null
      ? voiceService.resolveVoiceFilePath(refWavFileName)
      : null;
  return IrodoriEngineConfig(
    modelDir: modelDir,
    sampleRate: _irodoriSampleRate,
    refWavPath: refWavPath,
    speakerGuidanceScale: read(irodoriSpeakerGuidanceScaleProvider),
    captionGuidanceScale: read(irodoriCaptionGuidanceScaleProvider),
    numInferenceSteps: read(irodoriNumInferenceStepsProvider),
  );
}
