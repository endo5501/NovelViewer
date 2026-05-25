import 'package:novel_viewer/features/llm_summary/data/folder_file_lister.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_pipeline.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
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

  /// Runs analysis for `word` against files in `directoryPath` whose numeric
  /// prefix (or, for prefix-less files, lexical rank within the folder) is
  /// less than or equal to `coveredUpToEpisode`. The snapshot is then upserted
  /// at `(folderName, word, coveredUpToEpisode)`, with `sourceFileName`
  /// persisted as the jump target.
  Future<String> generateSummary({
    required String directoryPath,
    required String folderName,
    required String word,
    required int coveredUpToEpisode,
    String? sourceFileName,
    void Function(AnalysisProgress progress)? onProgress,
  }) async {
    try {
      final searchResults = await searchService.searchWithContext(
        directoryPath,
        word,
      );

      final filteredResults = _filterResultsByUpperBound(
        results: searchResults,
        upperBound: coveredUpToEpisode,
        directoryPath: directoryPath,
      );

      final contexts = _extractContexts(filteredResults);

      final pipeline = LlmSummaryPipeline(llmClient: llmClient);
      final summary = await pipeline.generate(
        word: word,
        contexts: contexts,
        onProgress: onProgress,
      );

      await repository.saveSnapshot(
        folderName: folderName,
        word: word,
        coveredUpToEpisode: coveredUpToEpisode,
        summary: summary,
        sourceFile: sourceFileName,
      );

      return summary;
    } finally {
      try {
        await llmClient.releaseResources();
      } catch (_) {
        // Release failures are not user-facing: preserve the original
        // generation outcome.
      }
    }
  }

  /// Keep search results whose file's effective episode number is
  /// `<= upperBound`. The lexical rank fallback for prefix-less files MUST be
  /// computed over the FOLDER's full text-file listing (not over the search
  /// result subset), so the bound here agrees with the one the trigger
  /// resolver computed when picking [upperBound]. Without that alignment,
  /// search-result-local ranks shift depending on which files happened to
  /// contain matches, leaking content from chapters past the user's current
  /// reading position.
  List<SearchResult> _filterResultsByUpperBound({
    required List<SearchResult> results,
    required int upperBound,
    required String directoryPath,
  }) {
    if (results.isEmpty) return results;

    // Build a lexical-rank map only when at least one search-result file
    // lacks a numeric prefix — avoids paying the directory-listing cost in
    // the common (well-numbered) case.
    Map<String, int>? lexicalRanks;
    final anyMissingPrefix =
        results.any((r) => extractNumericPrefix(r.fileName) == null);
    if (anyMissingPrefix) {
      final folderFiles = listSortedTextFileNames(directoryPath);
      lexicalRanks = {
        for (var i = 0; i < folderFiles.length; i++) folderFiles[i]: i + 1,
      };
    }

    return results.where((r) {
      final episode = _episodeFor(r.fileName, lexicalRanks);
      return episode != null && episode <= upperBound;
    }).toList();
  }

  static int? _episodeFor(String fileName, Map<String, int>? lexicalRanks) {
    final prefix = extractNumericPrefix(fileName);
    if (prefix != null) return prefix;
    return lexicalRanks?[fileName];
  }

  List<String> _extractContexts(List<SearchResult> results) {
    return results
        .expand(
            (r) => r.matches.map((m) => m.extendedContext ?? m.contextText))
        .toList();
  }
}
