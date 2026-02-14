import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';

class OpenAiCompatibleClient implements LlmClient {
  final String baseUrl;
  final String apiKey;
  final String model;
  final http.Client _httpClient;

  OpenAiCompatibleClient({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<String> generate(String prompt) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await _httpClient.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: headers,
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API error: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List;
    final message = choices[0]['message'] as Map<String, dynamic>;
    return message['content'] as String;
  }
}
