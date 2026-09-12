import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/foundation_models_client.dart';
import 'package:novel_viewer/features/llm_summary/data/ollama_client.dart';
import 'package:novel_viewer/features/llm_summary/data/openai_compatible_client.dart';

void main() {
  group('a client names the model behind it', () {
    test('the Ollama client names its provider and its model', () {
      final id = OllamaClient(
        baseUrl: 'http://localhost:11434',
        model: 'qwen3:30b',
      ).modelId;

      expect(id, isNotEmpty);
      expect(id, contains('ollama'));
      expect(id, contains('qwen3:30b'));
    });

    test('the OpenAI-compatible client names its provider and its model', () {
      final id = OpenAiCompatibleClient(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'k',
        model: 'gpt-4o-mini',
      ).modelId;

      expect(id, isNotEmpty);
      expect(id, contains('openai'));
      expect(id, contains('gpt-4o-mini'));
    });

    test('the on-device client names itself without configuration', () {
      expect(FoundationModelsClient().modelId, isNotEmpty);
    });

    test('the three providers never collide', () {
      final ids = {
        OllamaClient(baseUrl: 'http://a', model: 'm').modelId,
        OpenAiCompatibleClient(
          baseUrl: 'http://a',
          apiKey: '',
          model: 'm',
        ).modelId,
        FoundationModelsClient().modelId,
      };

      expect(ids, hasLength(3));
    });
  });

  group('what the identity does and does not depend on', () {
    test('the endpoint address does not change it', () {
      // The address says where a model is reached, not what it is. A reader's
      // self-hosted server moving to another IP must not orphan its cache.
      final atHome = OllamaClient(
        baseUrl: 'http://192.168.1.10:11434',
        model: 'qwen3:30b',
      ).modelId;
      final atWork = OllamaClient(
        baseUrl: 'http://10.0.0.5:11434',
        model: 'qwen3:30b',
      ).modelId;

      expect(atHome, atWork);
    });

    test('the API key does not change it', () {
      final withKey = OpenAiCompatibleClient(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'secret',
        model: 'gpt-4o-mini',
      ).modelId;
      final without = OpenAiCompatibleClient(
        baseUrl: 'https://api.example.com/v1',
        apiKey: '',
        model: 'gpt-4o-mini',
      ).modelId;

      expect(withKey, without);
    });

    test('two models under one provider are told apart', () {
      final small = OllamaClient(
        baseUrl: 'http://a',
        model: 'qwen3:8b',
      ).modelId;
      final large = OllamaClient(
        baseUrl: 'http://a',
        model: 'qwen3:30b',
      ).modelId;

      expect(small, isNot(large));
    });

    test('a model name containing the separator is carried whole', () {
      // Ollama names carry colons of their own. The identity is compared, not
      // parsed, so the name goes in as written.
      final id = OllamaClient(baseUrl: 'http://a', model: 'qwen3:30b').modelId;

      expect(id, endsWith('qwen3:30b'));
    });
  });
}
