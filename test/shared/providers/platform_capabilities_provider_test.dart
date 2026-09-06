import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
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
  group('per-feature providers derive from the capability model', () {
    test('all features report available when the model says so', () {
      final container = _containerWith(
        const PlatformCapabilities.forPlatform(isIOS: false),
      );

      expect(container.read(ttsSupportedProvider), isTrue);
      expect(container.read(appUpdateSupportedProvider), isTrue);
      expect(container.read(llmSummarySupportedProvider), isTrue);
    });

    test('all features report unavailable on the iOS capability set', () {
      final container = _containerWith(
        const PlatformCapabilities.forPlatform(isIOS: true),
      );

      expect(container.read(ttsSupportedProvider), isFalse);
      expect(container.read(appUpdateSupportedProvider), isFalse);
      expect(container.read(llmSummarySupportedProvider), isFalse);
    });

    test('withdrawing one feature leaves the others untouched', () {
      final container = _containerWith(
        const PlatformCapabilities(
          textToSpeech: true,
          appUpdate: false,
          llmSummary: true,
        ),
      );

      expect(container.read(appUpdateSupportedProvider), isFalse);
      expect(container.read(ttsSupportedProvider), isTrue);
      expect(container.read(llmSummarySupportedProvider), isTrue);
    });
  });

  test('the default implementation resolves the running platform', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // The test host is a desktop platform, so every feature is available. The
    // iOS branch is covered by the model's own test, which needs no platform.
    expect(
      container.read(platformCapabilitiesProvider).textToSpeech,
      !Platform.isIOS,
    );
    expect(container.read(ttsSupportedProvider), !Platform.isIOS);
  });
}
