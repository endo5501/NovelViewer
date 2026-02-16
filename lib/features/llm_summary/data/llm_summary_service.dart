import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_pipeline.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/text_search/data/search_models.dart';
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

    final filteredResults = _filterResultsIfNeeded(
      searchResults,
      summaryType,
      currentFileName,
    );

    final contexts = _extractContexts(filteredResults);

    final pipeline = LlmSummaryPipeline(llmClient: llmClient);
    final summary = await pipeline.generate(word: word, contexts: contexts);

    await repository.saveSummary(
      folderName: folderName,
      word: word,
      summaryType: summaryType,
      summary: summary,
      sourceFile: currentFileName,
    );

    return summary;
  }

  List<SearchResult> _filterResultsIfNeeded(
    List<SearchResult> results,
    SummaryType summaryType,
    String? currentFileName,
  ) {
    if (summaryType != SummaryType.noSpoiler) return results;
    if (currentFileName == null) return const [];

    final currentNum = _extractNumericPrefix(currentFileName);
    if (currentNum == null) {
      return results.where((r) => r.fileName == currentFileName).toList();
    }

    return results.where((r) {
      final num = _extractNumericPrefix(r.fileName);
      return num != null && num <= currentNum;
    }).toList();
  }

  List<String> _extractContexts(List<SearchResult> results) {
    return results
        .expand(
            (r) => r.matches.map((m) => m.extendedContext ?? m.contextText))
        .toList();
  }

  static int? _extractNumericPrefix(String fileName) {
    final match = RegExp(r'^(\d+)').firstMatch(fileName);
    return match != null ? int.parse(match.group(1)!) : null;
  }
}
