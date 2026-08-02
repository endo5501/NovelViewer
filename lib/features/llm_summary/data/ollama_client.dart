import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_format_exception.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';

class OllamaClient extends LlmClient {
  /// Upper bound on generated tokens per call. Valid fact/summary outputs
  /// measure well under half of this; the cap only cuts off runaway output.
  static const int maxOutputTokens = 1024;

  final String baseUrl;
  final String model;
  final http.Client _httpClient;

  /// Set once a server rejects the `think` parameter, so every later call is
  /// sent without it (and without a doomed first attempt).
  bool _thinkRejected = false;

  OllamaClient({
    required this.baseUrl,
    required this.model,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  static Future<List<String>> fetchModels({
    required String baseUrl,
    required http.Client httpClient,
  }) async {
    final response = await httpClient.get(Uri.parse('$baseUrl/api/tags'));
    final body = _decodeOk(response);

    final decoded = jsonDecode(body);
    final models = decoded is Map<String, dynamic> ? decoded['models'] : null;
    if (models is! List) {
      throw LlmResponseFormatException.withBody(
        'Ollama /api/tags response has no models list', body);
    }
    return models.map((m) {
      final name = m is Map<String, dynamic> ? m['name'] : null;
      if (name is! String) {
        throw LlmResponseFormatException.withBody(
          'Ollama model entry has a missing or non-string name', body);
      }
      return name;
    }).toList();
  }

  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async {
    // Thinking-capable models spend most of their time on reasoning tokens
    // that never reach the response, so thinking is disabled on every call.
    // `format` constrains decoding to the requested shape, which is what keeps
    // malformed answers (unescaped quotes, a list where a string is required)
    // from reaching the parser at all. Structured outputs have been available
    // since Ollama 0.5.0, so it is sent unconditionally with no fallback.
    final body = <String, dynamic>{
      'model': model,
      'prompt': prompt,
      'stream': false,
      'options': const {'num_predict': maxOutputTokens},
      if (schema != null) 'format': _formatFor(schema),
    };
    Map<String, dynamic> json;
    if (_thinkRejected) {
      json = await _postJson('/api/generate', body);
    } else {
      try {
        json = await _postJson('/api/generate', {...body, 'think': false});
      } on _OllamaStatusException catch (e) {
        // Some Ollama versions reject `think` for non-thinking models with a
        // 400. Fall back once without it and remember, so later calls are
        // sent once. Only 400 qualifies: other statuses (e.g. a 404 whose
        // body echoes a model name containing "thinking") must not silently
        // disable the optimization.
        if (e.statusCode != 400 || !e.body.contains('think')) rethrow;
        _thinkRejected = true;
        json = await _postJson('/api/generate', body);
      }
    }
    final response = json['response'];
    if (response is! String) {
      throw LlmResponseFormatException(
        'Ollama /api/generate response field is missing or not a string');
    }
    return response;
  }

  @override
  Future<void> releaseResources() async {
    await _postJson('/api/generate', {
      'model': model,
      'keep_alive': 0,
      'stream': false,
    });
  }

  /// Translates a response schema into Ollama's `format` field (a JSON Schema).
  static Map<String, dynamic> _formatFor(LlmResponseSchema schema) => {
        'type': 'object',
        'properties': {
          schema.fieldName: const {'type': 'string'},
        },
        'required': [schema.fieldName],
      };

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decodedBody = _decodeOk(response);
    final decoded = jsonDecode(decodedBody);
    if (decoded is! Map<String, dynamic>) {
      throw LlmResponseFormatException.withBody(
        'expected a JSON object at the top level', decodedBody);
    }
    return decoded;
  }

  /// Decodes the response body as UTF-8 (charset-independent) and throws on a
  /// non-200 status. Returns the decoded body for further parsing.
  /// `allowMalformed` so a non-UTF-8 error body does not throw FormatException
  /// before the status check (the status error message stays diagnosable).
  static String _decodeOk(http.Response response) {
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode != 200) {
      throw _OllamaStatusException(response.statusCode, body);
    }
    return body;
  }
}

/// Non-200 response from the Ollama API, keeping the error body inspectable
/// so `generate` can detect a rejected `think` parameter.
class _OllamaStatusException implements Exception {
  final int statusCode;
  final String body;

  _OllamaStatusException(this.statusCode, this.body);

  @override
  String toString() => 'Ollama API error: $statusCode $body';
}
