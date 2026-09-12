import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config_problem.dart';

void main() {
  LlmConfigProblem? problemFor(
    LlmProvider provider, {
    String baseUrl = 'http://localhost:11434',
    String model = 'llama3',
    String apiKey = 'sk-example',
  }) {
    return findLlmConfigProblem(
      LlmConfig(provider: provider, baseUrl: baseUrl, model: model),
      apiKey: apiKey,
    );
  }

  group('findLlmConfigProblem - no provider', () {
    test('reports noProvider even when server settings are filled in', () {
      expect(problemFor(LlmProvider.none), LlmConfigProblem.noProvider);
    });
  });

  group('findLlmConfigProblem - Ollama', () {
    test('finds nothing wrong with a complete configuration', () {
      expect(problemFor(LlmProvider.ollama), isNull);
    });

    test('reports a missing endpoint URL', () {
      expect(
        problemFor(LlmProvider.ollama, baseUrl: ''),
        LlmConfigProblem.missingEndpoint,
      );
    });

    test('reports a missing model name', () {
      expect(
        problemFor(LlmProvider.ollama, model: ''),
        LlmConfigProblem.missingModel,
      );
    });

    test('never asks for an API key', () {
      expect(problemFor(LlmProvider.ollama, apiKey: ''), isNull);
    });
  });

  group('findLlmConfigProblem - OpenAI-compatible', () {
    test('finds nothing wrong with a complete configuration', () {
      expect(problemFor(LlmProvider.openai), isNull);
    });

    test('reports a missing endpoint URL', () {
      expect(
        problemFor(LlmProvider.openai, baseUrl: ''),
        LlmConfigProblem.missingEndpoint,
      );
    });

    test('reports a missing model name', () {
      expect(
        problemFor(LlmProvider.openai, model: ''),
        LlmConfigProblem.missingModel,
      );
    });

    test('reports a missing API key', () {
      expect(
        problemFor(LlmProvider.openai, apiKey: ''),
        LlmConfigProblem.missingApiKey,
      );
    });
  });

  group('findLlmConfigProblem - on-device', () {
    test('is never judged by server settings', () {
      expect(
        problemFor(
          LlmProvider.appleOnDevice,
          baseUrl: '',
          model: '',
          apiKey: '',
        ),
        isNull,
      );
    });
  });

  group('findLlmConfigProblem - ordering', () {
    test('names the endpoint URL when everything is missing', () {
      expect(
        problemFor(LlmProvider.openai, baseUrl: '', model: '', apiKey: ''),
        LlmConfigProblem.missingEndpoint,
      );
    });

    test('names the model name when only the key is also missing', () {
      expect(
        problemFor(LlmProvider.openai, model: '', apiKey: ''),
        LlmConfigProblem.missingModel,
      );
    });
  });

  group('findLlmConfigProblem - whitespace', () {
    test('treats an endpoint URL of only whitespace as missing', () {
      expect(
        problemFor(LlmProvider.ollama, baseUrl: '   '),
        LlmConfigProblem.missingEndpoint,
      );
    });

    test('treats a model name of only whitespace as missing', () {
      expect(
        problemFor(LlmProvider.openai, model: ' \t '),
        LlmConfigProblem.missingModel,
      );
    });

    test('treats an API key of only whitespace as missing', () {
      expect(
        problemFor(LlmProvider.openai, apiKey: '  '),
        LlmConfigProblem.missingApiKey,
      );
    });
  });
}
