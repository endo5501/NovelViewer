import 'dart:io';

import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/folder_file_lister.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_pipeline.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
import 'package:novel_viewer/shared/utils/content_hash.dart';
import 'package:novel_viewer/features/text_search/data/search_models.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';

/// Groups one source file's search contexts so Stage-1 fact extraction (and
/// thus caching) happens at file granularity.
class _FileWork {
  final String fileName;
  final String filePath;
  final List<String> contexts = [];
  _FileWork({required this.fileName, required this.filePath});
}

class LlmSummaryService {
  final LlmClient llmClient;
  final LlmSummaryRepository repository;
  final FactCacheRepository factCacheRepository;
  final TextSearchService searchService;

  LlmSummaryService({
    required this.llmClient,
    required this.repository,
    required this.factCacheRepository,
    required this.searchService,
  });

  /// Runs analysis for `word` against files in `directoryPath` whose numeric
  /// prefix (or, for prefix-less files, lexical rank within the folder) is
  /// less than or equal to `coveredUpToEpisode`.
  ///
  /// Stage-1 fact extraction is assembled from the per-file fact cache: each
  /// in-scope file's cached facts are reused when still valid, and only cache
  /// misses are extracted (and written back). When a snapshot already exists at
  /// `coveredUpToEpisode`, this run is a re-analysis ("fix a bad result"), so
  /// the word's whole cache is invalidated up-front to force fresh extraction.
  /// The snapshot is then upserted at `(folderName, word, coveredUpToEpisode)`.
  Future<String> generateSummary({
    required String directoryPath,
    required String folderName,
    required String word,
    required int coveredUpToEpisode,
    String? sourceFileName,
    void Function(AnalysisProgress progress)? onProgress,
  }) async {
    try {
      // Re-analysis detection: an existing snapshot at this exact upper bound
      // means the user is overwriting a prior result. Invalidate the word's
      // whole cache so every in-scope file is re-extracted rather than served
      // from cache (restores "re-analyze = redo from scratch").
      final existing = await repository.findSnapshotsForWord(
        folderName: folderName,
        word: word,
      );
      final isReanalysis =
          existing.any((s) => s.coveredUpToEpisode == coveredUpToEpisode);
      if (isReanalysis) {
        await factCacheRepository.invalidateWord(
          folderName: folderName,
          word: word,
        );
      }

      final searchResults = await searchService.searchWithContext(
        directoryPath,
        word,
      );

      final filteredResults = _filterResultsByUpperBound(
        results: searchResults,
        upperBound: coveredUpToEpisode,
        directoryPath: directoryPath,
      );

      final files = _groupByFile(filteredResults);

      final pipeline = LlmSummaryPipeline(llmClient: llmClient);

      // Resolve hit/miss for each file before extracting, so progress totals
      // reflect only the files actually extracted (the misses).
      const currentPromptVersion = FactCacheRepository.currentPromptVersion;
      final cachedFactsByFile = <String, String?>{};
      final currentHashByFile = <String, String>{};
      for (final file in files) {
        final currentHash = await _hashFile(file.filePath);
        currentHashByFile[file.fileName] = currentHash;
        final cached = await factCacheRepository.find(
          folderName: folderName,
          word: word,
          fileName: file.fileName,
        );
        final valid = isFactCacheValid(
          cached,
          currentHash: currentHash,
          currentPromptVersion: currentPromptVersion,
        );
        cachedFactsByFile[file.fileName] = valid ? cached!.facts : null;
      }
      final missCount =
          cachedFactsByFile.values.where((f) => f == null).length;

      final perFileFacts = <String>[];
      var missDone = 0;
      for (final file in files) {
        final cachedFacts = cachedFactsByFile[file.fileName];
        if (cachedFacts != null) {
          perFileFacts.add(cachedFacts);
          continue;
        }
        missDone++;
        _notify(
          onProgress,
          AnalysisExtractingFacts(
            round: 1,
            current: missDone,
            total: missCount,
          ),
        );
        final facts = await pipeline.extractFileFacts(
          word: word,
          contexts: file.contexts,
        );
        await factCacheRepository.upsert(
          folderName: folderName,
          word: word,
          fileName: file.fileName,
          facts: facts,
          contentHash: currentHashByFile[file.fileName]!,
          promptVersion: currentPromptVersion,
        );
        perFileFacts.add(facts);
      }

      final summary = await pipeline.summarizeFromFacts(
        word: word,
        perFileFacts: perFileFacts,
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

  /// Group search results by source file, preserving deterministic file order
  /// (lexical by file name) so the assembled facts and progress counters are
  /// stable across runs.
  List<_FileWork> _groupByFile(List<SearchResult> results) {
    final byFile = <String, _FileWork>{};
    for (final r in results) {
      final work = byFile.putIfAbsent(
        r.fileName,
        () => _FileWork(fileName: r.fileName, filePath: r.filePath),
      );
      for (final m in r.matches) {
        work.contexts.add(m.extendedContext ?? m.contextText);
      }
    }
    final files = byFile.values.toList()
      ..sort((a, b) => a.fileName.compareTo(b.fileName));
    return files;
  }

  /// Hash the file's full content. On any read failure return the sentinel so
  /// the file is always treated as a miss (we never serve possibly-stale facts
  /// for a file we couldn't read).
  Future<String> _hashFile(String filePath) async {
    try {
      final content = await File(filePath).readAsString();
      return computeContentHash(content);
    } catch (_) {
      return FactCacheRepository.sentinelHash;
    }
  }

  static void _notify(
    void Function(AnalysisProgress)? onProgress,
    AnalysisProgress event,
  ) {
    if (onProgress == null) return;
    try {
      onProgress(event);
    } catch (_) {
      // A buggy UI listener must never abort data-layer generation.
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
}
