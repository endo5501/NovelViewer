import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_variant.dart';

void main() {
  group('IrodoriModelVariant', () {
    test('exposes exactly the v3 and v4 variants', () {
      expect(IrodoriModelVariant.values, [
        IrodoriModelVariant.v3,
        IrodoriModelVariant.v4,
      ]);
    });

    test('v3 supports caption, v4 does not', () {
      // v4 adds a trailing phrase that is not in the text whenever a
      // reference voice and a caption are supplied together (design D7 /
      // spec irodori-model-variant). Reference-only is clean, so v4 stays
      // usable — but caption must never reach it.
      expect(IrodoriModelVariant.v3.supportsCaption, isTrue);
      expect(IrodoriModelVariant.v4.supportsCaption, isFalse);
    });

    test('each variant names the directory holding its single GGUF', () {
      expect(
        IrodoriModelVariant.v3.modelDirName,
        'Irodori-TTS-600M-v3-VoiceDesign-GGUF',
      );
      expect(
        IrodoriModelVariant.v4.modelDirName,
        'Irodori-TTS-v4-Small-GGUF',
      );
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
          variant.ggufFileName,
          contains('f16'),
          reason: 'only f16 packages may be distributed',
        );
        expect(variant.ggufFileName, isNot(contains('q8_0')));
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
        expect(
          IrodoriModelVariant.fromStorageKey(variant.storageKey),
          variant,
        );
      }
    });

    test('falls back to v3 for an unknown or null storage key', () {
      // v3 is the default so an unreadable preference never silently moves a
      // user onto the caption-less variant.
      expect(IrodoriModelVariant.fromStorageKey(null), IrodoriModelVariant.v3);
      expect(IrodoriModelVariant.fromStorageKey(''), IrodoriModelVariant.v3);
      expect(
        IrodoriModelVariant.fromStorageKey('v99'),
        IrodoriModelVariant.v3,
      );
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
