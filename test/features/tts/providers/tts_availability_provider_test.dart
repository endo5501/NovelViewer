import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/providers/tts_availability_provider.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';

ProviderContainer _containerWith(PlatformCapabilities capabilities) {
  final container = ProviderContainer(
    overrides: [platformCapabilitiesProvider.overrideWithValue(capabilities)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('supportedTtsEnginesProvider', () {
    test('a desktop platform offers every engine in display order', () {
      final container = _containerWith(
        const PlatformCapabilities.forPlatform(isIOS: false, isMacOS: true),
      );

      expect(container.read(supportedTtsEnginesProvider), [
        TtsEngineType.qwen3,
        TtsEngineType.piper,
        TtsEngineType.irodori,
      ]);
    });

    test('iOS offers Piper and Irodori-TTS', () {
      final container = _containerWith(
        const PlatformCapabilities.forPlatform(isIOS: true, isMacOS: false),
      );

      expect(container.read(supportedTtsEnginesProvider), [
        TtsEngineType.piper,
        TtsEngineType.irodori,
      ]);
    });

    test('lists exactly the engines the capability model supports', () {
      final container = _containerWith(
        const PlatformCapabilities(
          piperTts: false,
          qwen3Tts: true,
          irodoriTts: true,
          ttsAudioExport: true,
          appUpdate: true,
          llmSummary: true,
          onDeviceLlm: false,
        ),
      );

      expect(container.read(supportedTtsEnginesProvider), [
        TtsEngineType.qwen3,
        TtsEngineType.irodori,
      ]);
    });
  });

  group('ttsAudioExportSupportedProvider', () {
    test('is available on a desktop platform', () {
      final container = _containerWith(
        const PlatformCapabilities.forPlatform(isIOS: false, isMacOS: false),
      );

      expect(container.read(ttsAudioExportSupportedProvider), isTrue);
    });

    test('is unavailable on iOS', () {
      final container = _containerWith(
        const PlatformCapabilities.forPlatform(isIOS: true, isMacOS: false),
      );

      expect(container.read(ttsAudioExportSupportedProvider), isFalse);
    });
  });

  group('irodoriRuntimeProvider', () {
    test('is audio.cpp on a desktop platform', () {
      final container = _containerWith(
        const PlatformCapabilities.forPlatform(isIOS: false, isMacOS: true),
      );

      expect(container.read(irodoriRuntimeProvider), IrodoriRuntime.audioCpp);
    });

    test('is speech.cpp on iOS', () {
      final container = _containerWith(
        const PlatformCapabilities.forPlatform(isIOS: true, isMacOS: false),
      );

      expect(container.read(irodoriRuntimeProvider), IrodoriRuntime.speechCpp);
    });
  });

  group('voice library feature providers', () {
    test('are all available on a desktop platform', () {
      final container = _containerWith(
        const PlatformCapabilities.forPlatform(isIOS: false, isMacOS: false),
      );

      expect(container.read(voiceRecordingSupportedProvider), isTrue);
      expect(container.read(voiceFileDragDropSupportedProvider), isTrue);
      expect(container.read(voicesFolderRevealSupportedProvider), isTrue);
    });

    test('are all unavailable on iOS', () {
      final container = _containerWith(
        const PlatformCapabilities.forPlatform(isIOS: true, isMacOS: false),
      );

      expect(container.read(voiceRecordingSupportedProvider), isFalse);
      expect(container.read(voiceFileDragDropSupportedProvider), isFalse);
      expect(container.read(voicesFolderRevealSupportedProvider), isFalse);
    });

    test('each follows its own capability', () {
      final container = _containerWith(
        const PlatformCapabilities(
          piperTts: true,
          qwen3Tts: true,
          irodoriTts: true,
          ttsAudioExport: true,
          appUpdate: true,
          llmSummary: true,
          onDeviceLlm: false,
          voiceRecording: false,
          voiceFileDragDrop: true,
          voicesFolderReveal: false,
        ),
      );

      expect(container.read(voiceRecordingSupportedProvider), isFalse);
      expect(container.read(voiceFileDragDropSupportedProvider), isTrue);
      expect(container.read(voicesFolderRevealSupportedProvider), isFalse);
    });
  });

  test('speech stays available on iOS through Piper', () {
    final container = _containerWith(
      const PlatformCapabilities.forPlatform(isIOS: true, isMacOS: false),
    );

    expect(container.read(ttsSupportedProvider), isTrue);
  });
}
