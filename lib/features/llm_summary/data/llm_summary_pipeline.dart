import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:novel_viewer/features/llm_summary/data/context_chunker.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_prompt_builder.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_format_exception.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';

final _log = Logger('llm_summary');

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
    void Function(AnalysisProgress progress)? onProgress,
  }) async {
    // Isolate UI-callback failures so a buggy progress listener can never
    // abort data-layer generation (and waste LLM tokens already consumed).
    final notify = _isolatedNotifier(onProgress);

    if (contexts.isEmpty) {
      notify(const AnalysisGeneratingFinalSummary());
      final prompt = LlmPromptBuilder.buildFinalSummaryPrompt(
        word: word,
        facts: '',
      );
      return _parseSummaryResponse(await llmClient.generate(prompt));
    }

    final facts = await _extractFactsRecursive(word, contexts, 0, notify);

    notify(const AnalysisGeneratingFinalSummary());
    final prompt = LlmPromptBuilder.buildFinalSummaryPrompt(
      word: word,
      facts: facts,
    );
    return _parseSummaryResponse(await llmClient.generate(prompt));
  }

  /// Stage-1 for a single source file: split this file's own contexts into
  /// chunks (only chunking when the file alone exceeds [maxChunkSize]) and
  /// combine the per-chunk extracted facts into the file's facts. Returns an
  /// empty string and makes no LLM call when [contexts] is empty. Contexts
  /// from other files are never passed here — the caller groups by file, which
  /// is what makes the result cacheable per `(folder, word, file)`.
  Future<String> extractFileFacts({
    required String word,
    required List<String> contexts,
  }) async {
    if (contexts.isEmpty) return '';
    final chunks = ContextChunker.split(contexts, maxChunkSize: maxChunkSize);
    final factsList = <String>[];
    for (final chunk in chunks) {
      final contextBlock = chunk.join('\n---\n');
      final prompt = LlmPromptBuilder.buildFactExtractionPrompt(
        word: word,
        contextChunk: contextBlock,
      );
      factsList.add(_parseFactsResponse(await llmClient.generate(prompt)));
    }
    return factsList.join('\n');
  }

  /// Aggregate already-extracted per-file facts and generate the final summary.
  /// When the combined facts exceed [maxChunkSize], runs recursive refinement
  /// (rounds 2+) before summarizing; otherwise goes straight to the final
  /// summary. Round-1 (per-file) progress is emitted by the caller, so this
  /// method only emits refinement rounds and the final-summary event.
  Future<String> summarizeFromFacts({
    required String word,
    required List<String> perFileFacts,
    void Function(AnalysisProgress progress)? onProgress,
  }) async {
    final notify = _isolatedNotifier(onProgress);

    final nonEmpty =
        perFileFacts.where((f) => f.trim().isNotEmpty).toList(growable: false);

    String facts;
    if (nonEmpty.isEmpty) {
      facts = '';
    } else {
      final combined = nonEmpty.join('\n');
      if (combined.length <= maxChunkSize) {
        facts = combined;
      } else {
        // Refinement starts at depth 1 so the first emitted round is 2.
        facts = await _extractFactsRecursive(word, nonEmpty, 1, notify);
      }
    }

    notify(const AnalysisGeneratingFinalSummary());
    final prompt = LlmPromptBuilder.buildFinalSummaryPrompt(
      word: word,
      facts: facts,
    );
    return _parseSummaryResponse(await llmClient.generate(prompt));
  }

  static void Function(AnalysisProgress) _isolatedNotifier(
    void Function(AnalysisProgress)? onProgress,
  ) {
    if (onProgress == null) return (_) {};
    return (event) {
      try {
        onProgress(event);
      } catch (e, st) {
        _log.warning('onProgress callback threw; ignoring', e, st);
      }
    };
  }

  Future<String> _extractFactsRecursive(
    String word,
    List<String> entries,
    int depth,
    void Function(AnalysisProgress progress) notify,
  ) async {
    if (depth >= maxRecursionDepth) {
      return entries.join('\n');
    }

    final chunks = ContextChunker.split(entries, maxChunkSize: maxChunkSize);
    final round = depth + 1;

    final factsList = <String>[];
    for (var i = 0; i < chunks.length; i++) {
      notify(AnalysisExtractingFacts(
        round: round,
        current: i + 1,
        total: chunks.length,
      ));
      final contextBlock = chunks[i].join('\n---\n');
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

    return _extractFactsRecursive(word, factsList, depth + 1, notify);
  }

  String _parseFactsResponse(String response) =>
      _parseJsonResponse(response, 'facts');

  String _parseSummaryResponse(String response) =>
      _parseJsonResponse(response, 'summary');

  String _parseJsonResponse(String response, String key) {
    final normalized = _stripCodeFence(response.trim());

    final dynamic decoded;
    try {
      decoded = jsonDecode(normalized);
    } catch (e, st) {
      // Decode failed: the model returned plain (non-JSON) text. Fall back to
      // the raw text (existing behavior) so the user-visible feature keeps
      // working, but log so prompt regressions become observable. Cap the
      // prefix at 200 chars to bound log size.
      final length = normalized.length;
      final prefix = length <= 200 ? normalized : normalized.substring(0, 200);
      _log.warning(
          'jsonDecode failed for $key; using raw text. length=$length prefix=$prefix',
          e,
          st);
      return normalized;
    }

    // Decode succeeded. A well-formed JSON object whose key holds a string is
    // the happy path. Anything else (non-object, key absent, or non-string
    // value such as {"summary": null}) is a malformed structured response: do
    // NOT persist the raw JSON as the value (regression for F132).
    if (decoded is Map<String, dynamic> && decoded[key] is String) {
      return decoded[key] as String;
    }

    final length = normalized.length;
    final prefix = length <= 200 ? normalized : normalized.substring(0, 200);
    _log.warning(
        'LLM response for $key decoded as JSON but had no string value; '
        'rejecting. length=$length prefix=$prefix');
    throw LlmResponseFormatException.withBody(
      'LLM response for "$key" has no string value', normalized);
  }

  static String _stripCodeFence(String s) {
    final m = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(s);
    return m?.group(1)?.trim() ?? s;
  }
}
