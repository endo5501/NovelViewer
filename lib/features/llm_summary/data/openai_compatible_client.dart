import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_format_exception.dart';

class OpenAiCompatibleClient extends LlmClient {
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

    // Decode UTF-8 from the raw bytes: real OpenAI-compatible endpoints return
    // a bare `application/json` with no charset, and `response.body` would then
    // latin1-decode the bytes and mangle non-ASCII (e.g. Japanese) text.
    // `allowMalformed` so a non-UTF-8 error body (e.g. a proxy's latin1 502
    // page) does not throw FormatException before the status check below.
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API error: ${response.statusCode} $body',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw LlmResponseFormatException.withBody(
        'expected a JSON object at the top level', body);
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw LlmResponseFormatException.withBody(
        'response has no choices', body);
    }
    final first = choices[0];
    final message = first is Map<String, dynamic> ? first['message'] : null;
    final content = message is Map<String, dynamic> ? message['content'] : null;
    if (content is! String) {
      throw LlmResponseFormatException.withBody(
        'choices[0].message.content is missing or not a string', body);
    }
    return content;
  }
}
