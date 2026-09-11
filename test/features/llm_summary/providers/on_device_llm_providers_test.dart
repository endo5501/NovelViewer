import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_models_llm/foundation_models_llm.dart';
import 'package:novel_viewer/features/llm_summary/providers/on_device_llm_providers.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';

/// Records whether it was asked at all, which is the point of most of these.
class _CountingPlugin implements FoundationModelsLlm {
  _CountingPlugin(this.answer);

  final OnDeviceModelAvailability answer;
  int asked = 0;

  @override
  Future<OnDeviceModelAvailability> availability() async {
    asked++;
    return answer;
  }

  @override
  Future<String> generate({
    required String prompt,
    String? schemaFieldName,
    int? maxResponseTokens,
  }) async => throw UnimplementedError();
}

void main() {
  ProviderContainer containerWith({
    required bool platformCanHost,
    required _CountingPlugin plugin,
  }) {
    final container = ProviderContainer(
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(
          PlatformCapabilities(
            textToSpeech: true,
            appUpdate: true,
            llmSummary: true,
            onDeviceLlm: platformCanHost,
          ),
        ),
        foundationModelsLlmProvider.overrideWithValue(plugin),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'reports the platform cannot host it, without asking the native side',
    () async {
      final plugin = _CountingPlugin(OnDeviceModelAvailability.available);
      final container = containerWith(platformCanHost: false, plugin: plugin);

      expect(
        await container.read(onDeviceModelAvailabilityProvider.future),
        OnDeviceModelAvailability.unsupportedPlatform,
      );
      expect(plugin.asked, 0);
    },
  );

  test('asks the native side where the platform can host it', () async {
    final plugin = _CountingPlugin(OnDeviceModelAvailability.available);
    final container = containerWith(platformCanHost: true, plugin: plugin);

    expect(
      await container.read(onDeviceModelAvailabilityProvider.future),
      OnDeviceModelAvailability.available,
    );
    expect(plugin.asked, 1);
  });

  test('carries each reason through to its consumers', () async {
    for (final reason in [
      OnDeviceModelAvailability.deviceNotEligible,
      OnDeviceModelAvailability.intelligenceNotEnabled,
      OnDeviceModelAvailability.modelNotReady,
    ]) {
      final container = containerWith(
        platformCanHost: true,
        plugin: _CountingPlugin(reason),
      );

      expect(
        await container.read(onDeviceModelAvailabilityProvider.future),
        reason,
        reason: '$reason',
      );
    }
  });

  test('picks up a state the reader changed, when asked again', () async {
    var answer = OnDeviceModelAvailability.intelligenceNotEnabled;
    final container = ProviderContainer(
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(
          const PlatformCapabilities(
            textToSpeech: true,
            appUpdate: true,
            llmSummary: true,
            onDeviceLlm: true,
          ),
        ),
        foundationModelsLlmProvider.overrideWith(
          (ref) => _AnswerHolder(() => answer),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(onDeviceModelAvailabilityProvider.future),
      OnDeviceModelAvailability.intelligenceNotEnabled,
    );

    answer = OnDeviceModelAvailability.available;
    container.invalidate(onDeviceModelAvailabilityProvider);

    expect(
      await container.read(onDeviceModelAvailabilityProvider.future),
      OnDeviceModelAvailability.available,
    );
  });

  test('the platform-layer provider reads the capability model', () {
    final container = containerWith(
      platformCanHost: true,
      plugin: _CountingPlugin(OnDeviceModelAvailability.available),
    );

    expect(container.read(onDeviceLlmSupportedProvider), isTrue);
  });
}

/// Answers whatever the closure says at the moment it is asked.
class _AnswerHolder implements FoundationModelsLlm {
  _AnswerHolder(this.answer);

  final OnDeviceModelAvailability Function() answer;

  @override
  Future<OnDeviceModelAvailability> availability() async => answer();

  @override
  Future<String> generate({
    required String prompt,
    String? schemaFieldName,
    int? maxResponseTokens,
  }) async => throw UnimplementedError();
}
