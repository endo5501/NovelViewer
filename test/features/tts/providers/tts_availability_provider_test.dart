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

    test('iOS offers Piper only', () {
      final container = _containerWith(
        const PlatformCapabilities.forPlatform(isIOS: true, isMacOS: false),
      );

      expect(container.read(supportedTtsEnginesProvider), [
        TtsEngineType.piper,
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

  test('speech stays available on iOS through Piper', () {
    final container = _containerWith(
      const PlatformCapabilities.forPlatform(isIOS: true, isMacOS: false),
    );

    expect(container.read(ttsSupportedProvider), isTrue);
  });
}
