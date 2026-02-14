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
