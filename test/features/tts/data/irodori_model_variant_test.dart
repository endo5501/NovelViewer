import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_variant.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';

void main() {
  group('IrodoriModelVariant', () {
    test('exposes the v3, v4 and v4.1 MF variants', () {
      expect(IrodoriModelVariant.values, [
        IrodoriModelVariant.v3,
        IrodoriModelVariant.v4,
        IrodoriModelVariant.v41Mf,
      ]);
    });

    test('v3 and v4 run on audio.cpp, v4.1 MF on speech.cpp', () {
      expect(IrodoriModelVariant.v3.runtime, IrodoriRuntime.audioCpp);
      expect(IrodoriModelVariant.v4.runtime, IrodoriRuntime.audioCpp);
      expect(IrodoriModelVariant.v41Mf.runtime, IrodoriRuntime.speechCpp);
    });

    test('only the audio.cpp variants accept the guidance settings', () {
      // MeanFlow folded the guidance into its training, and speech.cpp
      // refuses the guidance options on v4.1 Small MF.
      expect(IrodoriModelVariant.v3.acceptsGuidance, isTrue);
      expect(IrodoriModelVariant.v4.acceptsGuidance, isTrue);
      expect(IrodoriModelVariant.v41Mf.acceptsGuidance, isFalse);
    });

    test('v4.1 MF takes a caption and needs no duration correction', () {
      // speech.cpp passes the caption as `instructions` and ends the speech
      // where it goes silent, so there is no surplus length to bound.
      expect(IrodoriModelVariant.v41Mf.supportsCaption, isTrue);
      expect(IrodoriModelVariant.v41Mf.needsDurationCorrection, isFalse);
    });

    test('v4.1 MF is pinned by revision, size and SHA-256', () {
      const variant = IrodoriModelVariant.v41Mf;
      expect(variant.storageKey, 'v4.1-mf');
      expect(variant.modelDirName, 'Irodori-TTS-v4.1-Small-MF-GGUF');
      expect(variant.ggufFileName, 'Irodori-TTS-866M-MF-v4.1-F16.gguf');
      expect(variant.expectedFileSize, 1920321792);
      expect(
        variant.sha256,
        'e237dc3eefe469b8bba87872beacf12fb7fe00dbdf85767edca8ec04ab910d13',
      );
      expect(
        variant.downloadUrl,
        'https://huggingface.co/sakasegawa/Irodori-TTS-v4.1-Small-MF-GGUF/'
        'resolve/9db7da1bec3d1069ef8e29732e0497be60c7b047/'
        'Irodori-TTS-866M-MF-v4.1-F16.gguf',
      );
    });

    test('v3 and v4 keep their source and are checked by size only', () {
      expect(
        IrodoriModelVariant.v3.downloadUrl,
        'https://huggingface.co/endo5501/audio.cpp/resolve/main/'
        'Irodori-TTS-600M-v3-VoiceDesign-GGUF/'
        'irodori-tts-600m-v3-voicedesign-f16.gguf',
      );
      expect(
        IrodoriModelVariant.v4.downloadUrl,
        'https://huggingface.co/endo5501/audio.cpp/resolve/main/'
        'Irodori-TTS-v4-Small-GGUF/irodori-tts-v4-small-f16.gguf',
      );
      expect(IrodoriModelVariant.v3.sha256, isNull);
      expect(IrodoriModelVariant.v4.sha256, isNull);
    });

    test('the audio.cpp variants support caption', () {
      // v4 used to be excluded: it adds a trailing phrase that is not in the
      // text when a reference voice and a caption are supplied together. The
      // engine's duration correction removes that, so the flag is kept for a
      // future variant that needs excluding rather than for v4.
      expect(IrodoriModelVariant.v3.supportsCaption, isTrue);
      expect(IrodoriModelVariant.v4.supportsCaption, isTrue);
    });

    test('only v4 needs duration correction', () {
      // The correction is calibrated on v4: 0.207 s per spoken codepoint,
      // fitted on three v4 measurements. v3 never showed the trailing phrase,
      // and its captioned output already ends only 0.12 s inside what the
      // character rule would allow — applying the v4 bound to it risks cutting
      // speech that is correct today.
      expect(IrodoriModelVariant.v3.needsDurationCorrection, isFalse);
      expect(IrodoriModelVariant.v4.needsDurationCorrection, isTrue);
    });

    test('each variant names the directory holding its single GGUF', () {
      expect(
        IrodoriModelVariant.v3.modelDirName,
        'Irodori-TTS-600M-v3-VoiceDesign-GGUF',
      );
      expect(IrodoriModelVariant.v4.modelDirName, 'Irodori-TTS-v4-Small-GGUF');
    });

    test('each variant names its f16 GGUF file', () {
      // q8_0 must not be distributed: ggml's Vulkan backend saturates its
      // output to a constant full scale with q8_0 weights (design D7).
      expect(
        IrodoriModelVariant.v3.ggufFileName,
        'irodori-tts-600m-v3-voicedesign-f16.gguf',
      );
      expect(
        IrodoriModelVariant.v4.ggufFileName,
        'irodori-tts-v4-small-f16.gguf',
      );
      for (final variant in IrodoriModelVariant.values) {
        expect(
          variant.ggufFileName.toLowerCase(),
          contains('f16'),
          reason: 'only f16 packages may be distributed',
        );
        expect(variant.ggufFileName.toLowerCase(), isNot(contains('q8_0')));
      }
    });

    test('pins the exact byte size of each GGUF', () {
      // Sizes are pinned so a corrupt-but-complete transfer can never read as
      // "downloaded" (memory: project-piper-model-runner-mismatch).
      expect(IrodoriModelVariant.v3.expectedFileSize, 1463787680);
      expect(IrodoriModelVariant.v4.expectedFileSize, 1762161536);
    });

    test('round-trips through its storage key', () {
      for (final variant in IrodoriModelVariant.values) {
        expect(IrodoriModelVariant.fromStorageKey(variant.storageKey), variant);
      }
    });

    test('falls back to v3 for an unknown or null storage key', () {
      // v3 is the default so an unreadable preference never silently moves a
      // user onto the caption-less variant.
      expect(IrodoriModelVariant.fromStorageKey(null), IrodoriModelVariant.v3);
      expect(IrodoriModelVariant.fromStorageKey(''), IrodoriModelVariant.v3);
      expect(IrodoriModelVariant.fromStorageKey('v99'), IrodoriModelVariant.v3);
    });

    test('has a human-readable label for the settings UI', () {
      for (final variant in IrodoriModelVariant.values) {
        expect(variant.label, isNotEmpty);
      }
      expect(IrodoriModelVariant.v3.label, contains('v3'));
      expect(IrodoriModelVariant.v4.label, contains('v4'));
    });
  });
}
