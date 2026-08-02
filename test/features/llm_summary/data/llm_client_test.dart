import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_format_exception.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/data/ollama_client.dart';
import 'package:novel_viewer/features/llm_summary/data/openai_compatible_client.dart';

class _MinimalLlmClient extends LlmClient {
  LlmResponseSchema? receivedSchema;

  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async {
    receivedSchema = schema;
    return '';
  }
}

void main() {
  group('LlmClient default behavior', () {
    test('default releaseResources is a no-op that completes successfully',
        () async {
      final client = _MinimalLlmClient();
      await expectLater(client.releaseResources(), completes);
    });

    test('generate accepts an optional response schema', () async {
      final client = _MinimalLlmClient();

      await client.generate(
        'p',
        schema: const LlmResponseSchema.singleStringField('facts'),
      );

      expect(
        client.receivedSchema,
        const LlmResponseSchema.singleStringField('facts'),
      );
    });

    test('generate defaults to no schema when the argument is omitted',
        () async {
      final client = _MinimalLlmClient();

      await client.generate('p');

      expect(client.receivedSchema, isNull);
    });
  });

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

    group('releaseResources', () {
      test(
          'sends POST with model, keep_alive=0, stream=false, and no prompt field',
          () async {
        Uri? capturedUrl;
        String? capturedMethod;
        Map<String, dynamic>? capturedBody;

        final mockClient = MockClient((request) async {
          capturedUrl = request.url;
          capturedMethod = request.method;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'done': true}), 200);
        });

        final client = OllamaClient(
          baseUrl: 'http://localhost:11434',
          model: 'llama3',
          httpClient: mockClient,
        );

        await client.releaseResources();

        expect(capturedUrl.toString(), 'http://localhost:11434/api/generate');
        expect(capturedMethod, 'POST');
        expect(capturedBody!['model'], 'llama3');
        expect(capturedBody!['keep_alive'], 0);
        expect(capturedBody!['stream'], false);
        expect(capturedBody!.containsKey('prompt'), isFalse);
      });

      test('throws when server returns non-success status', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        final client = OllamaClient(
          baseUrl: 'http://localhost:11434',
          model: 'llama3',
          httpClient: mockClient,
        );

        expect(client.releaseResources(), throwsException);
      });

      test('propagates network errors from underlying http client', () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('connection refused');
        });

        final client = OllamaClient(
          baseUrl: 'http://localhost:11434',
          model: 'llama3',
          httpClient: mockClient,
        );

        expect(client.releaseResources(), throwsA(isA<SocketException>()));
      });
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

  group('OllamaClient generation efficiency', () {
    OllamaClient clientWith(MockClient mockClient) => OllamaClient(
          baseUrl: 'http://localhost:11434',
          model: 'gemma4:e4b',
          httpClient: mockClient,
        );

    http.Response okResponse() =>
        http.Response(jsonEncode({'response': 'ok'}), 200);

    test('generate sends think:false and options.num_predict=1024', () async {
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return okResponse();
      });

      await clientWith(mockClient).generate('p');

      expect(capturedBody!['think'], false);
      final options = capturedBody!['options'] as Map<String, dynamic>;
      expect(options['num_predict'], 1024);
    });

    test('releaseResources sends neither think nor options', () async {
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'done': true}), 200);
      });

      await clientWith(mockClient).releaseResources();

      expect(capturedBody!.containsKey('think'), isFalse);
      expect(capturedBody!.containsKey('options'), isFalse);
    });

    test('think-related error triggers a single retry without think',
        () async {
      final bodies = <Map<String, dynamic>>[];
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        bodies.add(body);
        if (body.containsKey('think')) {
          return http.Response(
            '"gemma4:e4b" does not support thinking',
            400,
          );
        }
        return okResponse();
      });

      final result = await clientWith(mockClient).generate('p');

      expect(result, 'ok');
      expect(bodies, hasLength(2));
      expect(bodies[0]['think'], false);
      expect(bodies[1].containsKey('think'), isFalse);
      // The retry keeps the other fields intact.
      expect(bodies[1]['prompt'], 'p');
      expect(
        (bodies[1]['options'] as Map<String, dynamic>)['num_predict'],
        1024,
      );
    });

    test('subsequent generate calls skip think after fallback', () async {
      final bodies = <Map<String, dynamic>>[];
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        bodies.add(body);
        if (body.containsKey('think')) {
          return http.Response('model does not support thinking', 400);
        }
        return okResponse();
      });

      final client = clientWith(mockClient);
      await client.generate('first');
      bodies.clear();

      final result = await client.generate('second');

      expect(result, 'ok');
      expect(bodies, hasLength(1));
      expect(bodies[0].containsKey('think'), isFalse);
    });

    test('non-400 errors mentioning think are not retried', () async {
      // A 404 for a model whose name contains "thinking" echoes that name in
      // the error body; it must not trip the think fallback.
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          'model "qwen3:30b-thinking" not found',
          404,
        );
      });

      await expectLater(
        () => clientWith(mockClient).generate('p'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          contains('404'),
        )),
      );
      expect(requestCount, 1);
    });

    test('errors unrelated to think are propagated without retry', () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('Server Error', 500);
      });

      await expectLater(
        () => clientWith(mockClient).generate('p'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          contains('500'),
        )),
      );
      expect(requestCount, 1);
    });
  });

  group('OllamaClient structured output', () {
    OllamaClient clientWith(MockClient mockClient) => OllamaClient(
          baseUrl: 'http://localhost:11434',
          model: 'gemma4:e4b',
          httpClient: mockClient,
        );

    http.Response okResponse() =>
        http.Response(jsonEncode({'response': 'ok'}), 200);

    test('generate with a schema sends format as a JSON Schema object',
        () async {
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return okResponse();
      });

      await clientWith(mockClient).generate(
        'p',
        schema: const LlmResponseSchema.singleStringField('facts'),
      );

      expect(capturedBody!['format'], {
        'type': 'object',
        'properties': {
          'facts': {'type': 'string'},
        },
        'required': ['facts'],
      });
      // The efficiency parameters stay in place alongside the schema.
      expect(capturedBody!['think'], false);
      expect(
        (capturedBody!['options'] as Map<String, dynamic>)['num_predict'],
        1024,
      );
    });

    test('generate without a schema omits format', () async {
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return okResponse();
      });

      await clientWith(mockClient).generate('p');

      expect(capturedBody!.containsKey('format'), isFalse);
    });

    test('releaseResources sends no format field', () async {
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'done': true}), 200);
      });

      await clientWith(mockClient).releaseResources();

      expect(capturedBody!.containsKey('format'), isFalse);
    });

    test('the think fallback retry keeps the format schema', () async {
      final bodies = <Map<String, dynamic>>[];
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        bodies.add(body);
        if (body.containsKey('think')) {
          return http.Response('model does not support thinking', 400);
        }
        return okResponse();
      });

      await clientWith(mockClient).generate(
        'p',
        schema: const LlmResponseSchema.singleStringField('summary'),
      );

      expect(bodies, hasLength(2));
      expect(bodies[1].containsKey('think'), isFalse);
      expect(
        (bodies[1]['format'] as Map<String, dynamic>)['required'],
        ['summary'],
      );
    });

    test('a 400 mentioning format is propagated without retry', () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('unknown parameter "format"', 400);
      });

      await expectLater(
        () => clientWith(mockClient).generate(
          'p',
          schema: const LlmResponseSchema.singleStringField('facts'),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          contains('400'),
        )),
      );
      expect(requestCount, 1);
    });

    test('a format-related failure does not disable the schema for later calls',
        () async {
      final bodies = <Map<String, dynamic>>[];
      var failFirst = true;
      final mockClient = MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (failFirst) {
          failFirst = false;
          return http.Response('unknown parameter "format"', 400);
        }
        return okResponse();
      });

      final client = clientWith(mockClient);
      const schema = LlmResponseSchema.singleStringField('facts');
      await expectLater(
        () => client.generate('first', schema: schema),
        throwsA(isA<Exception>()),
      );

      await client.generate('second', schema: schema);

      expect(bodies, hasLength(2));
      expect(bodies[1].containsKey('format'), isTrue);
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

    test('generate accepts a schema and leaves the request body unchanged',
        () async {
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
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
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
        model: 'gpt-4o-mini',
        httpClient: mockClient,
      );

      final result = await client.generate(
        'test prompt',
        schema: const LlmResponseSchema.singleStringField('summary'),
      );

      expect(result, 'response');
      expect(capturedBody!.keys, unorderedEquals(['model', 'messages']));
    });

    test('releaseResources sends no HTTP request and completes', () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('', 200);
      });

      final client = OpenAiCompatibleClient(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
        model: 'gpt-4o-mini',
        httpClient: mockClient,
      );

      await expectLater(client.releaseResources(), completes);
      expect(requestCount, 0);
    });
  });

  group('OpenAiCompatibleClient robustness', () {
    OpenAiCompatibleClient clientWith(MockClient mockClient) =>
        OpenAiCompatibleClient(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'sk-test',
          model: 'gpt-4o-mini',
          httpClient: mockClient,
        );

    test('decodes UTF-8 body without a charset declaration (no mojibake)',
        () async {
      const japanese = 'アリスは王国の第三王女。';
      final mockClient = MockClient((request) async {
        // Real OpenAI-compatible endpoints return a bare application/json with
        // no charset. http.Response.body would latin1-decode these bytes.
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'choices': [
              {
                'message': {'content': japanese},
              }
            ],
          })),
          200,
        );
      });

      final result = await clientWith(mockClient).generate('p');
      expect(result, japanese);
    });

    test('empty choices array throws LlmResponseFormatException (not RangeError)',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'choices': []}), 200);
      });

      expect(
        () => clientWith(mockClient).generate('p'),
        throwsA(isA<LlmResponseFormatException>()),
      );
    });

    test('missing message content throws LlmResponseFormatException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {'message': <String, dynamic>{}},
            ],
          }),
          200,
        );
      });

      expect(
        () => clientWith(mockClient).generate('p'),
        throwsA(isA<LlmResponseFormatException>()),
      );
    });

    test('non-string message content throws LlmResponseFormatException',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': null},
              }
            ],
          }),
          200,
        );
      });

      expect(
        () => clientWith(mockClient).generate('p'),
        throwsA(isA<LlmResponseFormatException>()),
      );
    });

    test('non-object top-level JSON throws LlmResponseFormatException',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode([1, 2, 3]), 200);
      });

      expect(
        () => clientWith(mockClient).generate('p'),
        throwsA(isA<LlmResponseFormatException>()),
      );
    });

    test('non-200 error body is decoded as UTF-8 in the exception message',
        () async {
      const japaneseError = 'エラーが発生しました';
      final mockClient = MockClient((request) async {
        return http.Response.bytes(utf8.encode(japaneseError), 500);
      });

      await expectLater(
        () => clientWith(mockClient).generate('p'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'toString',
            contains(japaneseError),
          ),
        ),
      );
    });

    test('non-200 with a non-UTF-8 body still throws the status error '
        '(not FormatException)', () async {
      final mockClient = MockClient((request) async {
        // Invalid UTF-8 byte sequence (lone 0xFF) in an error body.
        return http.Response.bytes([0xff, 0xfe, 0x80], 502);
      });

      await expectLater(
        () => clientWith(mockClient).generate('p'),
        throwsA(
          isA<Exception>()
              .having((e) => e, 'not FormatException',
                  isNot(isA<FormatException>()))
              .having((e) => e.toString(), 'toString', contains('502')),
        ),
      );
    });
  });

  group('OllamaClient robustness', () {
    OllamaClient generateClient(MockClient mockClient) => OllamaClient(
          baseUrl: 'http://localhost:11434',
          model: 'llama3',
          httpClient: mockClient,
        );

    test('generate decodes UTF-8 body without a charset declaration', () async {
      const japanese = 'これは日本語の応答です。';
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'response': japanese})),
          200,
        );
      });

      final result = await generateClient(mockClient).generate('p');
      expect(result, japanese);
    });

    test('generate with non-string response field throws '
        'LlmResponseFormatException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'response': null}), 200);
      });

      expect(
        () => generateClient(mockClient).generate('p'),
        throwsA(isA<LlmResponseFormatException>()),
      );
    });

    test('generate with missing response field throws '
        'LlmResponseFormatException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'done': true}), 200);
      });

      expect(
        () => generateClient(mockClient).generate('p'),
        throwsA(isA<LlmResponseFormatException>()),
      );
    });

    test('fetchModels decodes UTF-8 model names without a charset declaration',
        () async {
      const japaneseModel = 'モデル名:latest';
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'models': [
              {'name': japaneseModel},
            ],
          })),
          200,
        );
      });

      final result = await OllamaClient.fetchModels(
        baseUrl: 'http://localhost:11434',
        httpClient: mockClient,
      );
      expect(result, [japaneseModel]);
    });

    test('fetchModels with non-list models field throws '
        'LlmResponseFormatException (not TypeError)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'models': null}), 200);
      });

      expect(
        () => OllamaClient.fetchModels(
          baseUrl: 'http://localhost:11434',
          httpClient: mockClient,
        ),
        throwsA(isA<LlmResponseFormatException>()),
      );
    });

    test('fetchModels with non-string model name throws '
        'LlmResponseFormatException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'models': [
              {'name': 123},
            ],
          }),
          200,
        );
      });

      expect(
        () => OllamaClient.fetchModels(
          baseUrl: 'http://localhost:11434',
          httpClient: mockClient,
        ),
        throwsA(isA<LlmResponseFormatException>()),
      );
    });

    test('non-200 error body is decoded as UTF-8 in the exception message',
        () async {
      const japaneseError = 'サーバエラー';
      final mockClient = MockClient((request) async {
        return http.Response.bytes(utf8.encode(japaneseError), 500);
      });

      await expectLater(
        () => generateClient(mockClient).generate('p'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'toString',
            contains(japaneseError),
          ),
        ),
      );
    });
  });
}
