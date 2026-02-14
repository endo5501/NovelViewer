import 'dart:convert';

import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_prompt_builder.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';

class LlmSummaryService {
  final LlmClient llmClient;
  final LlmSummaryRepository repository;
  final TextSearchService searchService;

  LlmSummaryService({
    required this.llmClient,
    required this.repository,
    required this.searchService,
  });

  Future<String> generateSummary({
    required String directoryPath,
    required String folderName,
    required String word,
    required SummaryType summaryType,
    String? currentFileName,
  }) async {
    final searchResults = await searchService.searchWithContext(
      directoryPath,
      word,
    );

    var contexts = searchResults
        .expand((r) => r.matches.map((m) => m.extendedContext ?? m.contextText))
        .toList();

    if (summaryType == SummaryType.noSpoiler && currentFileName != null) {
      final currentNum = _extractNumericPrefix(currentFileName);
      if (currentNum != null) {
        final filteredResults = searchResults.where((r) {
          final num = _extractNumericPrefix(r.fileName);
          return num != null && num <= currentNum;
        }).toList();
        contexts = filteredResults
            .expand(
                (r) => r.matches.map((m) => m.extendedContext ?? m.contextText))
            .toList();
      }
    }

    final prompt = summaryType == SummaryType.spoiler
        ? LlmPromptBuilder.buildSpoilerPrompt(word: word, contexts: contexts)
        : LlmPromptBuilder.buildNoSpoilerPrompt(
            word: word, contexts: contexts);

    final response = await llmClient.generate(prompt);
    final summary = _parseResponse(response);

    await repository.saveSummary(
      folderName: folderName,
      word: word,
      summaryType: summaryType,
      summary: summary,
      sourceFile: currentFileName,
    );

    return summary;
  }

  String _parseResponse(String response) {
    try {
      final json = jsonDecode(response) as Map<String, dynamic>;
      if (json.containsKey('summary')) {
        return json['summary'] as String;
      }
    } catch (_) {}
    return response;
  }

  static int? _extractNumericPrefix(String fileName) {
    final match = RegExp(r'^(\d+)').firstMatch(fileName);
    return match != null ? int.parse(match.group(1)!) : null;
  }
}
