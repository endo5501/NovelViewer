import 'package:flutter/widgets.dart';
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
    OnDeviceSampling? sampling,
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

  group('the availability is re-asked when the app comes back', () {
    /// Changing the system intelligence feature means leaving the app, so
    /// coming back is the moment the cached answer is most likely stale.
    test('a resume re-asks the native side', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      var answer = OnDeviceModelAvailability.intelligenceNotEnabled;
      final plugin = _AnswerHolder(() => answer);
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
          foundationModelsLlmProvider.overrideWithValue(plugin),
        ],
      );
      addTearDown(container.dispose);

      final lifecycle = container.read(onDeviceAvailabilityLifecycleProvider);
      expect(
        await container.read(onDeviceModelAvailabilityProvider.future),
        OnDeviceModelAvailability.intelligenceNotEnabled,
      );

      answer = OnDeviceModelAvailability.available;
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(
        await container.read(onDeviceModelAvailabilityProvider.future),
        OnDeviceModelAvailability.available,
      );
    });

    test('any other lifecycle state leaves the cached answer alone', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      var asked = 0;
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
          foundationModelsLlmProvider.overrideWith((ref) {
            return _AnswerHolder(() {
              asked++;
              return OnDeviceModelAvailability.available;
            });
          }),
        ],
      );
      addTearDown(container.dispose);

      final lifecycle = container.read(onDeviceAvailabilityLifecycleProvider);
      await container.read(onDeviceModelAvailabilityProvider.future);
      expect(asked, 1);

      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await container.read(onDeviceModelAvailabilityProvider.future);

      expect(asked, 1);
    });

    test('the observer is actually registered with the binding', () async {
      // Driving the binding rather than the observer proves registration
      // happened, which calling the observer directly would not.
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      var answer = OnDeviceModelAvailability.modelNotReady;
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
          foundationModelsLlmProvider.overrideWithValue(
            _AnswerHolder(() => answer),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(onDeviceAvailabilityLifecycleProvider);
      await container.read(onDeviceModelAvailabilityProvider.future);

      answer = OnDeviceModelAvailability.available;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(
        await container.read(onDeviceModelAvailabilityProvider.future),
        OnDeviceModelAvailability.available,
      );
    });
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
    OnDeviceSampling? sampling,
  }) async => throw UnimplementedError();
}
