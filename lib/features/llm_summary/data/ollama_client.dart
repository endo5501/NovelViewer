import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_format_exception.dart';

class OllamaClient extends LlmClient {
  final String baseUrl;
  final String model;
  final http.Client _httpClient;

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
  Future<String> generate(String prompt) async {
    final json = await _postJson('/api/generate', {
      'model': model,
      'prompt': prompt,
      'stream': false,
    });
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
      throw Exception(
        'Ollama API error: ${response.statusCode} $body',
      );
    }
    return body;
  }
}
