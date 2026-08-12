import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_variant.dart';
import 'package:novel_viewer/features/tts/domain/tts_engine_config.dart';

void main() {
  IrodoriEngineConfig build({
    required IrodoriModelVariant variant,
    String modelDir = '/models/irodori',
    String? refWavPath = '/voice/narrator.wav',
    double captionGuidanceScale = 3.0,
  }) =>
      IrodoriEngineConfig(
        modelDir: modelDir,
        sampleRate: 48000,
        variant: variant,
        refWavPath: refWavPath,
        speakerGuidanceScale: 5.0,
        captionGuidanceScale: captionGuidanceScale,
        numInferenceSteps: 40,
      );

  group('IrodoriEngineConfig.variant', () {
    test('is carried on the config', () {
      expect(build(variant: IrodoriModelVariant.v4).variant,
          IrodoriModelVariant.v4);
      expect(build(variant: IrodoriModelVariant.v3).variant,
          IrodoriModelVariant.v3);
    });

    test('exposes caption support through the variant', () {
      expect(build(variant: IrodoriModelVariant.v3).supportsCaption, isTrue);
      expect(build(variant: IrodoriModelVariant.v4).supportsCaption, isTrue);
    });
  });

  group('IrodoriEngineConfig.modelLoadKey', () {
    test('changing the variant changes the load key', () {
      // Unlike caption / refWavPath / guidance / steps, the variant selects a
      // different GGUF on disk, so it must force a model reload.
      expect(
        build(variant: IrodoriModelVariant.v3).modelLoadKey,
        isNot(build(variant: IrodoriModelVariant.v4).modelLoadKey),
      );
    });

    test('same variant and dir produce an equal load key', () {
      expect(
        build(variant: IrodoriModelVariant.v4).modelLoadKey,
        build(variant: IrodoriModelVariant.v4).modelLoadKey,
      );
    });

    test('synthesis-time parameters stay out of the load key', () {
      // Changing a caption guidance scale must not reload the model.
      expect(
        build(variant: IrodoriModelVariant.v3, captionGuidanceScale: 3.0)
            .modelLoadKey,
        build(variant: IrodoriModelVariant.v3, captionGuidanceScale: 4.5)
            .modelLoadKey,
      );
      expect(
        build(variant: IrodoriModelVariant.v3, refWavPath: '/voice/a.wav')
            .modelLoadKey,
        build(variant: IrodoriModelVariant.v3, refWavPath: null).modelLoadKey,
      );
    });

    test('a different model dir still changes the load key', () {
      expect(
        build(variant: IrodoriModelVariant.v3, modelDir: '/models/a')
            .modelLoadKey,
        isNot(build(variant: IrodoriModelVariant.v3, modelDir: '/models/b')
            .modelLoadKey),
      );
    });
  });
}
