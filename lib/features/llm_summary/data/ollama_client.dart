import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';

class OllamaClient implements LlmClient {
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

    if (response.statusCode != 200) {
      throw Exception(
        'Ollama API error: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final models = json['models'] as List<dynamic>;
    return models
        .map((m) => (m as Map<String, dynamic>)['name'] as String)
        .toList();
  }

  @override
  Future<String> generate(String prompt) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/api/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'prompt': prompt,
        'stream': false,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Ollama API error: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['response'] as String;
  }
}
