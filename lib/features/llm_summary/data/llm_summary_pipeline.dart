import 'dart:convert';

import 'package:novel_viewer/features/llm_summary/data/context_chunker.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_prompt_builder.dart';

class LlmSummaryPipeline {
  final LlmClient llmClient;
  final int maxChunkSize;
  final int maxRecursionDepth;

  LlmSummaryPipeline({
    required this.llmClient,
    this.maxChunkSize = 4000,
    this.maxRecursionDepth = 5,
  });

  Future<String> generate({
    required String word,
    required List<String> contexts,
  }) async {
    if (contexts.isEmpty) {
      final prompt = LlmPromptBuilder.buildFinalSummaryPrompt(
        word: word,
        facts: '',
      );
      return _parseSummaryResponse(await llmClient.generate(prompt));
    }

    final facts = await _extractFactsRecursive(word, contexts, 0);

    final prompt = LlmPromptBuilder.buildFinalSummaryPrompt(
      word: word,
      facts: facts,
    );
    return _parseSummaryResponse(await llmClient.generate(prompt));
  }

  Future<String> _extractFactsRecursive(
    String word,
    List<String> entries,
    int depth,
  ) async {
    if (depth >= maxRecursionDepth) {
      return entries.join('\n');
    }

    final chunks = ContextChunker.split(entries, maxChunkSize: maxChunkSize);

    final factsList = <String>[];
    for (final chunk in chunks) {
      final contextBlock = chunk.join('\n---\n');
      final prompt = LlmPromptBuilder.buildFactExtractionPrompt(
        word: word,
        contextChunk: contextBlock,
      );
      final response = await llmClient.generate(prompt);
      factsList.add(_parseFactsResponse(response));
    }

    final combinedFacts = factsList.join('\n');
    final afterLen = factsList.fold<int>(0, (s, e) => s + e.length);
    final beforeLen = entries.fold<int>(0, (s, e) => s + e.length);

    if (combinedFacts.length <= maxChunkSize || afterLen >= beforeLen) {
      return combinedFacts;
    }

    return _extractFactsRecursive(word, factsList, depth + 1);
  }

  String _parseFactsResponse(String response) =>
      _parseJsonResponse(response, 'facts');

  String _parseSummaryResponse(String response) =>
      _parseJsonResponse(response, 'summary');

  String _parseJsonResponse(String response, String key) {
    final normalized = _stripCodeFence(response.trim());
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic> && decoded.containsKey(key)) {
        return decoded[key] as String;
      }
    } catch (_) {}
    return normalized;
  }

  static String _stripCodeFence(String s) {
    final m = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(s);
    return m?.group(1)?.trim() ?? s;
  }
}
