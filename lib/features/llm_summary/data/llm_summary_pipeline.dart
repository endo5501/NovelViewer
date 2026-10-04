import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:novel_viewer/features/llm_summary/data/context_chunker.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_prompt_builder.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_format_exception.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_analysis_failure.dart';

final _log = Logger('llm_summary');

/// One source file's Stage-1 result, together with how it was obtained.
///
/// [isStructured] is false when any chunk's response had to fall back to raw
/// text (it failed `jsonDecode`). Such a value is still usable for the current
/// run but must not be cached, or the fragment of malformed JSON would poison
/// every later analysis of that word.
class ExtractedFileFacts {
  const ExtractedFileFacts({required this.facts, required this.isStructured});

  final String facts;
  final bool isStructured;
}

/// A parsed response value plus whether it came from a structured decode.
class _ParsedValue {
  const _ParsedValue(this.value, {required this.isStructured});

  final String value;
  final bool isStructured;
}

/// One reference-source ancestor's Stage-1 facts, per file, with the title
/// its facts are labeled by.
class ReferenceSourceFacts {
  const ReferenceSourceFacts({required this.title, required this.perFileFacts});

  final String title;
  final List<String> perFileFacts;
}

class LlmSummaryPipeline {
  /// Shapes the two stages constrain their responses to. Requesting these
  /// keeps malformed answers from being generated in the first place, rather
  /// than relying on the parser to reject them after the fact.
  static const factsSchema = LlmResponseSchema.singleStringField('facts');

  /// What an aggregation round puts between the facts it hands over. It is
  /// counted when the round is sized, so the facts reach the prompt within
  /// the response budget rather than past it by the separators.
  static const _refinementSeparator = '\n---\n';
  static const summarySchema = LlmResponseSchema.singleStringField('summary');

  final LlmClient llmClient;
  final int maxChunkSize;

  /// What aggregation rounds are sized by. Unless given, the client's own
  /// response budget, capped at [maxChunkSize]: a round cannot be handed
  /// more than the window, and a client that declares no response budget
  /// answers with its own window, which can be larger than this one.
  final int maxResponseSize;
  final int maxRecursionDepth;

  /// UI display language (`ja`/`en`/`zh`) that both prompt stages instruct the
  /// LLM to answer in. One analysis run uses a single language, so it is fixed
  /// at construction time rather than per call.
  final String language;

  LlmSummaryPipeline({
    required this.llmClient,
    this.maxChunkSize = 4000,
    int? maxResponseSize,
    this.maxRecursionDepth = 5,
    this.language = 'ja',
  }) : maxResponseSize =
           maxResponseSize ?? min(llmClient.maxResponseSize, maxChunkSize);

  /// Stage-1 for a single source file: split this file's own contexts into
  /// chunks (only chunking when the file alone exceeds [maxChunkSize]) and
  /// combine the per-chunk extracted facts into the file's facts. Returns an
  /// empty, structured result and makes no LLM call when [contexts] is empty.
  /// Contexts from other files are never passed here — the caller groups by
  /// file, which is what makes the result cacheable per `(folder, word, file)`.
  ///
  /// The result reports whether every chunk decoded structurally. A single
  /// chunk that fell back to raw text marks the whole file unstructured,
  /// because the file's facts are the concatenation of its chunks and the
  /// caller caches (or withholds) them as one unit.
  Future<ExtractedFileFacts> extractFileFactsDetailed({
    required String word,
    required List<String> contexts,
  }) async {
    if (contexts.isEmpty) {
      return const ExtractedFileFacts(facts: '', isStructured: true);
    }
    final chunks = ContextChunker.split(contexts, maxChunkSize: maxChunkSize);
    final factsList = <String>[];
    var isStructured = true;
    for (final chunk in chunks) {
      final contextBlock = chunk.join('\n---\n');
      final prompt = LlmPromptBuilder.buildFactExtractionPrompt(
        word: word,
        contextChunk: contextBlock,
        language: language,
      );
      final parsed = await _generateFacts(prompt);
      factsList.add(parsed.value);
      isStructured = isStructured && parsed.isStructured;
    }
    return ExtractedFileFacts(
      facts: factsList.join('\n'),
      isStructured: isStructured,
    );
  }

  /// [extractFileFactsDetailed] without the parse provenance, for callers that
  /// only need the text.
  Future<String> extractFileFacts({
    required String word,
    required List<String> contexts,
  }) async =>
      (await extractFileFactsDetailed(word: word, contexts: contexts)).facts;

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

    final nonEmpty = _nonEmpty(perFileFacts);

    // With no facts there is nothing to summarize: asking the LLM anyway would
    // have it invent a summary from an empty evidence set, which then gets
    // saved as if it were grounded.
    if (nonEmpty.isEmpty) {
      throw const LlmAnalysisNoFactsFailure();
    }

    final String facts;
    final combined = nonEmpty.join('\n');
    if (combined.length <= maxChunkSize) {
      facts = combined;
    } else {
      final (aggregated, _) = await _aggregate(
        word,
        nonEmpty,
        target: maxChunkSize,
        firstRound: 2,
        notify: notify,
      );
      facts = _withinWindow(aggregated);
    }

    return _finalSummary(word, facts, notify, hasReferenceSources: false);
  }

  /// [summarizeFromFacts] with the facts of the novel's reference-source
  /// ancestors merged in.
  ///
  /// Each reference source is compressed on its own first, so a long parent
  /// work arrives as no more than one response's worth of facts instead of
  /// burying this work's. Its facts are then labeled line by line with the
  /// source's title and placed, in the given order, ahead of this work's own
  /// facts, which stay unlabeled. Per-line rather than one header per source:
  /// in the merged text a header would appear to cover this work's facts that
  /// follow it, and a header is lost whenever the chunker splits an entry.
  ///
  /// With no reference source contributing facts, this is
  /// [summarizeFromFacts] exactly — same requests, same prompts.
  Future<String> summarizeFromSources({
    required String word,
    required List<String> ownFacts,
    required List<ReferenceSourceFacts> referenceFacts,
    void Function(AnalysisProgress progress)? onProgress,
  }) async {
    final notify = _isolatedNotifier(onProgress);

    var round = 2;
    final labeled = <String>[];
    for (final source in referenceFacts) {
      final nonEmpty = _nonEmpty(source.perFileFacts);
      if (nonEmpty.isEmpty) continue;
      var facts = nonEmpty.join('\n');
      if (facts.length > maxResponseSize) {
        final (aggregated, nextRound) = await _aggregate(
          word,
          nonEmpty,
          target: maxResponseSize,
          firstRound: round,
          notify: notify,
        );
        round = nextRound;
        facts = _keepingHead(aggregated, maxResponseSize);
      }
      final labeledFacts = _labelLines(source.title, facts);
      if (labeledFacts.isNotEmpty) labeled.add(labeledFacts);
    }

    if (labeled.isEmpty) {
      return summarizeFromFacts(
        word: word,
        perFileFacts: ownFacts,
        onProgress: onProgress,
      );
    }

    final entries = [...labeled, ..._nonEmpty(ownFacts)];
    final String facts;
    final combined = entries.join('\n');
    if (combined.length <= maxChunkSize) {
      facts = combined;
    } else {
      final (aggregated, _) = await _aggregate(
        word,
        entries,
        target: maxChunkSize,
        firstRound: round,
        notify: notify,
        preserveSourceLabels: true,
      );
      // This work's facts sit at the end, so keeping the tail cuts from the
      // reference sources. Their lines carry their own labels, so whatever of
      // them survives the cut still says where it came from.
      facts = _keepingTail(aggregated, maxChunkSize);
    }

    return _finalSummary(word, facts, notify, hasReferenceSources: true);
  }

  Future<String> _finalSummary(
    String word,
    String facts,
    void Function(AnalysisProgress) notify, {
    required bool hasReferenceSources,
  }) async {
    notify(const AnalysisGeneratingFinalSummary());
    final prompt = LlmPromptBuilder.buildFinalSummaryPrompt(
      word: word,
      facts: facts,
      language: language,
      hasReferenceSources: hasReferenceSources,
    );
    final parsed = await _withSingleRetry(
      () async => _parseSummaryResponse(
        await llmClient.generate(prompt, schema: summarySchema),
      ),
    );
    return (await _readableOr(parsed, prompt)).value;
  }

  static List<String> _nonEmpty(List<String> facts) =>
      facts.where((f) => f.trim().isNotEmpty).toList(growable: false);

  static final _bullet = RegExp(r'^(\s*[-・*]\s*)(.*)$');

  /// [facts] with "『[title]』より: " on every non-blank line, after the bullet
  /// where the line has one.
  ///
  /// A line that would run past [maxResponseSize] once labeled is split into
  /// pieces that each carry the label. An aggregation round hard-splits any
  /// entry line longer than that budget, and the piece cut off there would
  /// otherwise reach the model unlabeled — read as this work's own fact.
  String _labelLines(String title, String facts) {
    final label = '『$title』より: ';
    final labeled = <String>[];
    for (final line in facts.split('\n')) {
      if (line.trim().isEmpty) continue;
      final m = _bullet.firstMatch(line);
      final prefix = m == null ? label : '${m.group(1)}$label';
      final text = m == null ? line : m.group(2)!;
      final room = max(1, maxResponseSize - prefix.length);
      for (var i = 0; i < text.length; i += room) {
        labeled.add('$prefix${text.substring(i, min(i + room, text.length))}');
      }
      if (text.isEmpty) labeled.add(prefix);
    }
    return labeled.join('\n');
  }

  /// The last part of [facts] that fits [limit], starting on a line where
  /// one falls within it.
  String _keepingTail(String facts, int limit) {
    if (facts.length <= limit) return facts;
    final breakAt = facts.indexOf('\n', facts.length - limit - 1);
    final kept = breakAt < 0
        ? facts.substring(facts.length - limit)
        : facts.substring(breakAt + 1);
    _log.warning(
      'merged facts exceed the window; keeping the tail. '
      'length=${facts.length} window=$limit kept=${kept.length}',
    );
    return kept;
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

  /// [facts], cut to what the final summary prompt can carry.
  ///
  /// Aggregation stops in three ways, and two of them — a round that did not
  /// shrink the facts, and the depth limit — stop without the facts having
  /// come within the window. Handed on as they are, they overrun the final
  /// summary request after every extraction has already been paid for.
  ///
  /// The cut is mechanical rather than another round, because both of those
  /// exits are reached precisely when another round would not help. It lands
  /// on a line break where one falls within the window, so no fact is left
  /// half-written for the summary to read as a fact of its own.
  String _withinWindow(String facts) => _keepingHead(facts, maxChunkSize);

  /// The first part of [facts] that fits [limit], ending on a line break
  /// where one falls within it.
  String _keepingHead(String facts, int limit) {
    if (facts.length <= limit) return facts;
    var cut = facts.lastIndexOf('\n', limit);
    if (cut <= 0) cut = limit;
    _log.warning(
      'aggregated facts exceed the window; cutting to fit. '
      'length=${facts.length} window=$limit kept=$cut',
    );
    return facts.substring(0, cut);
  }

  /// Merges [entries] in aggregation rounds until they fit [target], and
  /// returns the merged facts together with the round number the next
  /// aggregation should start from.
  ///
  /// Rounds are numbered from [firstRound], so several aggregations in one
  /// run (one per reference source, then the merged set) count on from one
  /// another and the progress shown never steps back. The depth limit counts
  /// rounds within this one aggregation.
  ///
  /// [preserveSourceLabels] asks each round to keep the "『作品名』より:" labels
  /// reference-source facts carry.
  Future<(String, int)> _aggregate(
    String word,
    List<String> entries, {
    required int target,
    required int firstRound,
    required void Function(AnalysisProgress progress) notify,
    bool preserveSourceLabels = false,
  }) async {
    var current = entries;
    var round = firstRound;
    for (var depth = 1; ; depth++) {
      if (depth >= maxRecursionDepth) {
        return (current.join('\n'), round);
      }

      // Sized by what the model may return, not by what it may be handed: a
      // round answers at close to the length of the facts it was given, so a
      // window-sized chunk asks for an answer the response cap cuts off.
      final chunks = ContextChunker.split(
        current,
        maxChunkSize: maxResponseSize,
        separator: _refinementSeparator,
      );

      final factsList = <String>[];
      for (var i = 0; i < chunks.length; i++) {
        notify(
          AnalysisExtractingFacts(
            round: round,
            current: i + 1,
            total: chunks.length,
          ),
        );
        final prompt = LlmPromptBuilder.buildFactRefinementPrompt(
          word: word,
          facts: chunks[i].join(_refinementSeparator),
          maxResponseSize: maxResponseSize,
          language: language,
          preserveSourceLabels: preserveSourceLabels,
        );
        factsList.add((await _generateFacts(prompt)).value);
      }
      round++;

      final combinedFacts = factsList.join('\n');
      final afterLen = factsList.fold<int>(0, (s, e) => s + e.length);
      final beforeLen = current.fold<int>(0, (s, e) => s + e.length);

      if (combinedFacts.length <= target || afterLen >= beforeLen) {
        return (combinedFacts, round);
      }
      current = factsList;
    }
  }

  /// Runs one Stage-1 extraction request and parses its response, retrying once
  /// on failure.
  Future<_ParsedValue> _generateFacts(String prompt) => _withSingleRetry(
    () async => _parseFactsResponse(
      await llmClient.generate(prompt, schema: factsSchema),
    ),
  );

  /// Retries [operation] exactly once, with no delay and no change to the
  /// request. One retry absorbs the transient failures that remain once the
  /// response schema rules out malformed output — a dropped connection, a 5xx,
  /// or a one-off answer the parser rejects. A second failure is not transient,
  /// so it propagates.
  static Future<T> _withSingleRetry<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e) {
      // A failure that knows an identical retry cannot help is not retried.
      // The second attempt would send the same prompt to the same model and
      // be refused, or overrun, for the same reason — at the cost of a full
      // generation.
      if (e is LlmRetryableFailure && !e.isWorthRetrying) rethrow;
      return await operation();
    }
  }

  /// [first], or one more answer to [prompt] when [first] could not be read.
  ///
  /// This stage is the one whose value the reader sees: it is saved as the
  /// word's summary with nothing downstream judging it, so an answer that fell
  /// back to raw text is shown as though it were a summary. That fallback used
  /// to mean the model had replied in prose, which reads acceptably. It now
  /// also covers an answer the response cap cut off mid-object, which does
  /// not, and which reaches here whenever a provider gives up a schema
  /// constraint to get an answer at all.
  ///
  /// One further request, and the first answer kept whatever it returns. Two
  /// unreadable answers are equally bad and one of them has to be shown, so
  /// there is nothing to gain by spending a third generation choosing between
  /// them — and this runs on the slowest provider there is.
  ///
  /// A second request that fails outright leaves the first answer standing. An
  /// answer in hand beats losing the run over an attempt to improve on it.
  ///
  /// Only the final summary is treated this way. An unreadable extraction is
  /// already marked unstructured, which keeps it out of the fact cache and
  /// costs the reader nothing beyond a re-extraction.
  Future<_ParsedValue> _readableOr(_ParsedValue first, String prompt) async {
    if (first.isStructured) return first;
    try {
      final second = _parseSummaryResponse(
        await llmClient.generate(prompt, schema: summarySchema),
      );
      return second.isStructured ? second : first;
    } catch (e, st) {
      _log.warning('second summary attempt failed; keeping the first', e, st);
      return first;
    }
  }

  _ParsedValue _parseFactsResponse(String response) =>
      _parseJsonResponse(response, 'facts');

  _ParsedValue _parseSummaryResponse(String response) =>
      _parseJsonResponse(response, 'summary');

  _ParsedValue _parseJsonResponse(String response, String key) {
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
        st,
      );
      return _ParsedValue(normalized, isStructured: false);
    }

    // Decode succeeded. A well-formed JSON object whose key holds a string is
    // the happy path. Anything else (non-object, key absent, or non-string
    // value such as {"summary": null}) is a malformed structured response: do
    // NOT persist the raw JSON as the value (regression for F132).
    if (decoded is Map<String, dynamic> && decoded[key] is String) {
      return _ParsedValue(decoded[key] as String, isStructured: true);
    }

    // Runtimes that ignore the requested `format` (e.g. Ollama's MLX runner)
    // let a capable model return a string array where a string was requested,
    // e.g. {"facts": ["fact1", "fact2"]}. The content is valid, so normalize a
    // non-empty array of strings into a single newline-joined string (no bullet
    // prefix is added or stripped) and treat it as a structured decode. An
    // empty array or one with a non-string element is not normalizable and
    // falls through to the malformed-response rejection below.
    final value = decoded is Map<String, dynamic> ? decoded[key] : null;
    if (value is List && value.isNotEmpty && value.every((e) => e is String)) {
      final joined = value.cast<String>().join('\n');
      return _ParsedValue(joined, isStructured: true);
    }

    final length = normalized.length;
    final prefix = length <= 200 ? normalized : normalized.substring(0, 200);
    _log.warning(
      'LLM response for $key decoded as JSON but had no string value; '
      'rejecting. length=$length prefix=$prefix',
    );
    throw LlmResponseFormatException.withBody(
      'LLM response for "$key" has no string value',
      normalized,
    );
  }

  static String _stripCodeFence(String s) {
    final m = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(s);
    return m?.group(1)?.trim() ?? s;
  }
}
