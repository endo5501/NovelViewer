import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/openai_compatible_client.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../test_utils/flutter_secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStorageMock secureStorageMock;

  setUp(() {
    secureStorageMock = FlutterSecureStorageMock();
    secureStorageMock.install();
  });

  tearDown(() {
    secureStorageMock.uninstall();
  });

  group('llmConfigProvider', () {
    test('returns default none config when no settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final config = container.read(llmConfigProvider);
      expect(config.provider, LlmProvider.none);
      expect(config.isConfigured, false);
    });

    test('returns configured Ollama settings', () async {
      SharedPreferences.setMockInitialValues({
        'llm_provider': 'ollama',
        'llm_base_url': 'http://localhost:11434',
        'llm_model': 'llama3',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final config = container.read(llmConfigProvider);
      expect(config.provider, LlmProvider.ollama);
      expect(config.baseUrl, 'http://localhost:11434');
      expect(config.model, 'llama3');
      expect(config.isConfigured, true);
    });
  });

  group('llmClientProvider', () {
    test('returns null when provider is none', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final client = await container.read(llmClientProvider.future);
      expect(client, isNull);
    });

    test(
        'returns OpenAiCompatibleClient configured with the API key fetched '
        'from secure storage when provider is openai', () async {
      SharedPreferences.setMockInitialValues({
        'llm_provider': 'openai',
        'llm_base_url': 'https://api.openai.com/v1',
        'llm_model': 'gpt-4o-mini',
      });
      secureStorageMock.store['llm_api_key'] = 'sk-from-secure';
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final client = await container.read(llmClientProvider.future);
      expect(client, isA<OpenAiCompatibleClient>());
      final openai = client as OpenAiCompatibleClient;
      expect(openai.apiKey, 'sk-from-secure');
      expect(openai.baseUrl, 'https://api.openai.com/v1');
      expect(openai.model, 'gpt-4o-mini');
    });

    test('returns null when openai provider has no API key in secure storage',
        () async {
      SharedPreferences.setMockInitialValues({
        'llm_provider': 'openai',
        'llm_base_url': 'https://api.openai.com/v1',
        'llm_model': 'gpt-4o-mini',
      });
      // No entry in secureStorageMock.store -> getApiKey returns ''
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final client = await container.read(llmClientProvider.future);
      expect(client, isNull);
    });

    test('does not call secure storage for the Ollama provider', () async {
      SharedPreferences.setMockInitialValues({
        'llm_provider': 'ollama',
        'llm_base_url': 'http://localhost:11434',
        'llm_model': 'llama3',
      });
      final prefs = await SharedPreferences.getInstance();

      // Replace the channel handler with a counter so we can assert that the
      // Ollama path never touches secure storage. The outer tearDown's
      // uninstall() handles cleanup.
      var secureCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async {
          secureCalls++;
          return null;
        },
      );

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final client = await container.read(llmClientProvider.future);
      expect(client, isNotNull);
      expect(secureCalls, 0);
    });
  });
}
