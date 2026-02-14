import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
        'llm_api_key': '',
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

    test('llmClientProvider returns null when not configured', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final client = container.read(llmClientProvider);
      expect(client, isNull);
    });
  });
}
