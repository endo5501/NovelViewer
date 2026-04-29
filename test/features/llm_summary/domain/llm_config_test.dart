import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';

void main() {
  group('LlmProvider', () {
    test('has three values: none, ollama, openai', () {
      expect(LlmProvider.values.length, 3);
      expect(LlmProvider.values, contains(LlmProvider.none));
      expect(LlmProvider.values, contains(LlmProvider.ollama));
      expect(LlmProvider.values, contains(LlmProvider.openai));
    });
  });

  group('LlmConfig', () {
    test('creates with provider, baseUrl and model', () {
      const config = LlmConfig(
        provider: LlmProvider.openai,
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
      );

      expect(config.provider, LlmProvider.openai);
      expect(config.baseUrl, 'https://api.openai.com/v1');
      expect(config.model, 'gpt-4o-mini');
    });

    test('creates with default none provider', () {
      const config = LlmConfig();

      expect(config.provider, LlmProvider.none);
      expect(config.baseUrl, '');
      expect(config.model, '');
    });

    test('creates Ollama config', () {
      const config = LlmConfig(
        provider: LlmProvider.ollama,
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
      );

      expect(config.provider, LlmProvider.ollama);
      expect(config.baseUrl, 'http://localhost:11434');
      expect(config.model, 'llama3');
    });

    test('isConfigured returns true when provider is not none', () {
      const config = LlmConfig(
        provider: LlmProvider.ollama,
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
      );

      expect(config.isConfigured, true);
    });

    test('isConfigured returns false when provider is none', () {
      const config = LlmConfig();

      expect(config.isConfigured, false);
    });

    test('does not expose an apiKey field (secrets live in secure storage)',
        () {
      const config = LlmConfig(
        provider: LlmProvider.openai,
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
      );

      // The intent is that LlmConfig has no apiKey accessor at all. Casting
      // to dynamic and probing keeps the test compilable while still failing
      // (NoSuchMethodError) if someone reintroduces the field.
      expect(
        () => (config as dynamic).apiKey,
        throwsNoSuchMethodError,
      );
    });
  });
}
