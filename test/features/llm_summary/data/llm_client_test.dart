import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/llm_summary/data/ollama_client.dart';
import 'package:novel_viewer/features/llm_summary/data/openai_compatible_client.dart';

void main() {
  group('OllamaClient', () {
    test('generate sends correct request and returns response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'http://localhost:11434/api/generate');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'llama3');
        expect(body['prompt'], 'test prompt');
        expect(body['stream'], false);
        return http.Response(
          jsonEncode({'response': 'test response'}),
          200,
        );
      });

      final client = OllamaClient(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        httpClient: mockClient,
      );

      final result = await client.generate('test prompt');
      expect(result, 'test response');
    });

    test('generate throws on non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final client = OllamaClient(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        httpClient: mockClient,
      );

      expect(
        () => client.generate('test prompt'),
        throwsException,
      );
    });

    group('fetchModels', () {
      test('returns model names from server response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), 'http://localhost:11434/api/tags');
          expect(request.method, 'GET');
          return http.Response(
            jsonEncode({
              'models': [
                {'name': 'gemma3', 'size': 3338801804},
                {'name': 'qwen3:8b', 'size': 5000000000},
                {'name': 'llama3.1:latest', 'size': 4000000000},
              ],
            }),
            200,
          );
        });

        final result = await OllamaClient.fetchModels(
          baseUrl: 'http://localhost:11434',
          httpClient: mockClient,
        );

        expect(result, ['gemma3', 'qwen3:8b', 'llama3.1:latest']);
      });

      test('returns empty list when no models installed', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'models': []}),
            200,
          );
        });

        final result = await OllamaClient.fetchModels(
          baseUrl: 'http://localhost:11434',
          httpClient: mockClient,
        );

        expect(result, isEmpty);
      });

      test('throws on non-200 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        expect(
          () => OllamaClient.fetchModels(
            baseUrl: 'http://localhost:11434',
            httpClient: mockClient,
          ),
          throwsException,
        );
      });
    });
  });

  group('OpenAiCompatibleClient', () {
    test('generate sends correct request with auth and returns response',
        () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.openai.com/v1/chat/completions',
        );
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer sk-test');
        expect(request.headers['Content-Type'], 'application/json');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'gpt-4o-mini');
        final messages = body['messages'] as List;
        expect(messages.length, 1);
        expect(messages[0]['role'], 'user');
        expect(messages[0]['content'], 'test prompt');
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'test response'},
              }
            ],
          }),
          200,
        );
      });

      final client = OpenAiCompatibleClient(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
        model: 'gpt-4o-mini',
        httpClient: mockClient,
      );

      final result = await client.generate('test prompt');
      expect(result, 'test response');
    });

    test('generate works without apiKey', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), false);
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'response'},
              }
            ],
          }),
          200,
        );
      });

      final client = OpenAiCompatibleClient(
        baseUrl: 'http://localhost:1234/v1',
        apiKey: '',
        model: 'local-model',
        httpClient: mockClient,
      );

      final result = await client.generate('prompt');
      expect(result, 'response');
    });

    test('generate throws on non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final client = OpenAiCompatibleClient(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'bad-key',
        model: 'gpt-4o-mini',
        httpClient: mockClient,
      );

      expect(
        () => client.generate('test prompt'),
        throwsException,
      );
    });
  });
}
