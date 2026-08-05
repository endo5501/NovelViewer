import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_variant.dart';
import 'package:novel_viewer/features/tts/domain/tts_engine_config.dart';

/// The v4 caption gate.
///
/// Irodori v4 appends a short phrase that is not in the text whenever a
/// reference voice and a caption are supplied together — measured at 10/10,
/// while reference-only and caption-only are both clean (design D7). This
/// app's main path is reference x caption, so caption must never reach v4.
///
/// The gate lives in [TtsEngineConfig.captionFromMemo] rather than in the
/// settings UI because synthesis is reached from three separate call sites
/// (streaming generation, the edit dialog's regenerate, and re-synthesis of a
/// stored segment). A UI-only gate would leak through the paths that never
/// touch the UI.
void main() {
  IrodoriEngineConfig irodori(IrodoriModelVariant variant) =>
      IrodoriEngineConfig(
        modelDir: '/models/irodori',
        sampleRate: 48000,
        variant: variant,
        refWavPath: '/voice/narrator.wav',
        speakerGuidanceScale: 5.0,
        captionGuidanceScale: 3.0,
        numInferenceSteps: 40,
      );

  group('captionFromMemo - v3 keeps caption', () {
    test('passes a non-empty memo through as the caption', () {
      expect(
        TtsEngineConfig.captionFromMemo(
          irodori(IrodoriModelVariant.v3),
          '怒って叫んでいる',
        ),
        '怒って叫んでいる',
      );
    });

    test('still maps null and empty memos to no caption', () {
      final config = irodori(IrodoriModelVariant.v3);
      expect(TtsEngineConfig.captionFromMemo(config, null), isNull);
      expect(TtsEngineConfig.captionFromMemo(config, ''), isNull);
    });
  });

  group('captionFromMemo - v4 drops caption', () {
    test('returns null for a non-empty memo', () {
      expect(
        TtsEngineConfig.captionFromMemo(
          irodori(IrodoriModelVariant.v4),
          '怒って叫んでいる',
        ),
        isNull,
      );
    });

    test('returns null regardless of memo content', () {
      final config = irodori(IrodoriModelVariant.v4);
      for (final memo in <String?>[
        null,
        '',
        ' ',
        'a',
        '落ち着いた大人の男性。深く響く声で丁寧に話している。',
        'x' * 1000,
      ]) {
        expect(
          TtsEngineConfig.captionFromMemo(config, memo),
          isNull,
          reason: 'v4 must never receive a caption (memo: "$memo")',
        );
      }
    });

    test('drops the caption even when no reference voice is set', () {
      // The measured failure needs reference x caption, but the gate is
      // unconditional: a config without a reference today may gain one from a
      // per-segment override before synthesis runs.
      const config = IrodoriEngineConfig(
        modelDir: '/models/irodori',
        sampleRate: 48000,
        variant: IrodoriModelVariant.v4,
        refWavPath: null,
        speakerGuidanceScale: 5.0,
        captionGuidanceScale: 3.0,
        numInferenceSteps: 40,
      );
      expect(TtsEngineConfig.captionFromMemo(config, '悲しげに'), isNull);
    });
  });

  group('captionFromMemo - other engines unchanged', () {
    test('Qwen3 never uses the memo as a caption', () {
      const config = Qwen3EngineConfig(
        modelDir: '/models/qwen3',
        sampleRate: 24000,
        languageId: 2058,
        refWavPath: '/voice/narrator.wav',
        embeddingCacheDir: '/cache',
      );
      expect(TtsEngineConfig.captionFromMemo(config, '怒って叫んでいる'), isNull);
    });

    test('Piper never uses the memo as a caption', () {
      const config = PiperEngineConfig(
        modelDir: '/models/piper/model.onnx',
        sampleRate: 22050,
        dicDir: '/dic',
        lengthScale: 1.0,
        noiseScale: 0.667,
        noiseW: 0.8,
      );
      expect(TtsEngineConfig.captionFromMemo(config, '怒って叫んでいる'), isNull);
    });
  });
}
