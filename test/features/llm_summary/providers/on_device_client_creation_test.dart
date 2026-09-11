import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_models_llm/foundation_models_llm.dart';
import 'package:novel_viewer/features/llm_summary/data/foundation_models_client.dart';
import 'package:novel_viewer/features/llm_summary/data/ollama_client.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/llm_summary/providers/on_device_llm_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../test_utils/flutter_secure_storage_mock.dart';

class _Plugin implements FoundationModelsLlm {
  _Plugin(this.answer);

  final OnDeviceModelAvailability answer;

  @override
  Future<OnDeviceModelAvailability> availability() async => answer;

  @override
  Future<String> generate({
    required String prompt,
    String? schemaFieldName,
    int? maxResponseTokens,
  }) async => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStorageMock secureStorageMock;

  setUp(() {
    secureStorageMock = FlutterSecureStorageMock();
    secureStorageMock.install();
  });

  tearDown(() => secureStorageMock.uninstall());

  /// A container whose stored settings are [stored] and whose on-device model
  /// reports [availability].
  Future<ProviderContainer> containerWith({
    required Map<String, Object> stored,
    required OnDeviceModelAvailability availability,
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        platformCapabilitiesProvider.overrideWithValue(
          const PlatformCapabilities(
            textToSpeech: true,
            appUpdate: true,
            llmSummary: true,
            onDeviceLlm: true,
          ),
        ),
        foundationModelsLlmProvider.overrideWithValue(_Plugin(availability)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('builds the on-device client when the model is available', () async {
    final container = await containerWith(
      stored: {'llm_provider': 'appleOnDevice'},
      availability: OnDeviceModelAvailability.available,
    );

    expect(
      await container.read(llmClientProvider.future),
      isA<FoundationModelsClient>(),
    );
  });

  test('builds no client at all when the model is unavailable', () async {
    final container = await containerWith(
      stored: {'llm_provider': 'appleOnDevice'},
      availability: OnDeviceModelAvailability.intelligenceNotEnabled,
    );

    expect(await container.read(llmClientProvider.future), isNull);
  });

  test(
    'does not fall back to a server the reader configured earlier',
    () async {
      // The endpoint and model of a previous Ollama setup are still stored.
      // Reaching for them when the on-device model goes away would send the
      // novel's text somewhere the reader chose this provider to avoid.
      final container = await containerWith(
        stored: {
          'llm_provider': 'appleOnDevice',
          'llm_base_url': 'http://localhost:11434',
          'llm_model': 'llama3',
        },
        availability: OnDeviceModelAvailability.intelligenceNotEnabled,
      );

      final client = await container.read(llmClientProvider.future);

      expect(client, isNull);
      expect(client, isNot(isA<OllamaClient>()));
    },
  );

  test('leaves the stored selection alone when availability is lost', () async {
    final container = await containerWith(
      stored: {'llm_provider': 'appleOnDevice'},
      availability: OnDeviceModelAvailability.intelligenceNotEnabled,
    );

    await container.read(llmClientProvider.future);

    expect(
      container.read(llmConfigProvider).provider,
      LlmProvider.appleOnDevice,
    );
  });

  test(
    'works again once availability returns, with no setting changed',
    () async {
      var answer = OnDeviceModelAvailability.intelligenceNotEnabled;
      SharedPreferences.setMockInitialValues({'llm_provider': 'appleOnDevice'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              textToSpeech: true,
              appUpdate: true,
              llmSummary: true,
              onDeviceLlm: true,
            ),
          ),
          foundationModelsLlmProvider.overrideWith((ref) => _Plugin(answer)),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(llmClientProvider.future), isNull);

      answer = OnDeviceModelAvailability.available;
      container.invalidate(foundationModelsLlmProvider);
      container.invalidate(onDeviceModelAvailabilityProvider);

      expect(
        await container.read(llmClientProvider.future),
        isA<FoundationModelsClient>(),
      );
      expect(
        container.read(llmConfigProvider).provider,
        LlmProvider.appleOnDevice,
      );
    },
  );

  test('a server provider is untouched by on-device availability', () async {
    final container = await containerWith(
      stored: {
        'llm_provider': 'ollama',
        'llm_base_url': 'http://localhost:11434',
        'llm_model': 'llama3',
      },
      availability: OnDeviceModelAvailability.deviceNotEligible,
    );

    expect(await container.read(llmClientProvider.future), isA<OllamaClient>());
  });
}
