import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';

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
    _ensureOk(response);

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final models = json['models'] as List<dynamic>;
    return models
        .map((m) => (m as Map<String, dynamic>)['name'] as String)
        .toList();
  }

  @override
  Future<String> generate(String prompt) async {
    final json = await _postJson('/api/generate', {
      'model': model,
      'prompt': prompt,
      'stream': false,
    });
    return json['response'] as String;
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
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static void _ensureOk(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception(
        'Ollama API error: ${response.statusCode} ${response.body}',
      );
    }
  }
}
