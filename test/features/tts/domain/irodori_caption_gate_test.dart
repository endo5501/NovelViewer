import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_variant.dart';
import 'package:novel_viewer/features/tts/domain/tts_engine_config.dart';

/// The caption gate.
///
/// Irodori v4 used to be excluded here: it appends a short phrase that is not
/// in the text whenever a reference voice and a caption are supplied together.
/// The cause was the duration predictor asking for more time than the text
/// needs, and the engine's duration correction removes it, so v4 now accepts
/// captions like v3.
///
/// The gate itself stays. It keeps the decision in one place below the UI —
/// synthesis is reached from three separate call sites (streaming generation,
/// the edit dialog's regenerate, and re-synthesis of a stored segment), and a
/// UI-only gate would leak through the paths that never touch the UI. Today it
/// only drops captions for the engines that have no caption conditioning at
/// all; a future variant that needs excluding changes this one function.
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

  group('captionFromMemo - v4 keeps caption', () {
    test('passes a non-empty memo through as the caption', () {
      expect(
        TtsEngineConfig.captionFromMemo(
          irodori(IrodoriModelVariant.v4),
          '怒って叫んでいる',
        ),
        '怒って叫んでいる',
      );
    });

    test('passes the memo through whatever its content', () {
      final config = irodori(IrodoriModelVariant.v4);
      for (final memo in <String>[
        ' ',
        'a',
        '落ち着いた大人の男性。深く響く声で丁寧に話している。',
        'x' * 1000,
      ]) {
        expect(
          TtsEngineConfig.captionFromMemo(config, memo),
          memo,
          reason: 'v4 accepts captions now (memo: "$memo")',
        );
      }
    });

    test('still maps null and empty memos to no caption', () {
      final config = irodori(IrodoriModelVariant.v4);
      expect(TtsEngineConfig.captionFromMemo(config, null), isNull);
      expect(TtsEngineConfig.captionFromMemo(config, ''), isNull);
    });

    test('passes the caption through with no reference voice set', () {
      // The failure this gate used to prevent needed reference x caption, but
      // the correction covers the no-reference path too, and a config without
      // a reference today may gain one from a per-segment override before
      // synthesis runs.
      const config = IrodoriEngineConfig(
        modelDir: '/models/irodori',
        sampleRate: 48000,
        variant: IrodoriModelVariant.v4,
        refWavPath: null,
        speakerGuidanceScale: 5.0,
        captionGuidanceScale: 3.0,
        numInferenceSteps: 40,
      );
      expect(TtsEngineConfig.captionFromMemo(config, '悲しげに'), '悲しげに');
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
