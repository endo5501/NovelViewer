import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_format_exception.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_pipeline.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';

class _MockLlmClient extends LlmClient {
  final List<String> responses;
  final List<String> prompts = [];
  int _callIndex = 0;

  _MockLlmClient(this.responses);

  @override
  Future<String> generate(String prompt) async {
    prompts.add(prompt);
    final response = responses[_callIndex % responses.length];
    _callIndex++;
    return response;
  }

  int get callCount => _callIndex;
}

void main() {
  group('LlmSummaryPipeline.extractFileFacts (per-file Stage-1)', () {
    test('small single-file contexts produce one extraction call', () async {
      final mock = _MockLlmClient([
        jsonEncode({'facts': '- 王国の王女'}),
      ]);
      final pipeline = LlmSummaryPipeline(llmClient: mock);

      final facts = await pipeline.extractFileFacts(
        word: 'アリス',
        contexts: ['アリスは王国の王女として登場した。'],
      );

      expect(facts, '- 王国の王女');
      expect(mock.callCount, 1);
    });

    test('a file whose contexts exceed the chunk size is chunked internally',
        () async {
      // 3 entries of 20 chars each, maxChunkSize 25 → 3 internal chunks.
      final mock = _MockLlmClient([
        jsonEncode({'facts': '- f1'}),
        jsonEncode({'facts': '- f2'}),
        jsonEncode({'facts': '- f3'}),
      ]);
      final pipeline = LlmSummaryPipeline(llmClient: mock, maxChunkSize: 25);

      final facts = await pipeline.extractFileFacts(
        word: 'アリス',
        contexts: ['あ' * 20, 'い' * 20, 'う' * 20],
      );

      expect(mock.callCount, 3, reason: 'one extraction per internal chunk');
      expect(facts, '- f1\n- f2\n- f3',
          reason: 'per-chunk facts are combined into the file facts');
    });

    test('an oversized single entry is its own chunk (one call)', () async {
      final mock = _MockLlmClient([
        jsonEncode({'facts': '- huge'}),
      ]);
      final pipeline = LlmSummaryPipeline(llmClient: mock, maxChunkSize: 10);

      final facts = await pipeline.extractFileFacts(
        word: 'アリス',
        contexts: ['あ' * 500],
      );

      expect(mock.callCount, 1);
      expect(facts, '- huge');
    });

    test('empty contexts make no LLM call and return empty facts', () async {
      final mock = _MockLlmClient([jsonEncode({'facts': '- x'})]);
      final pipeline = LlmSummaryPipeline(llmClient: mock);

      final facts = await pipeline.extractFileFacts(word: 'アリス', contexts: []);

      expect(facts, isEmpty);
      expect(mock.callCount, 0);
    });
  });

  group('LlmSummaryPipeline.summarizeFromFacts (aggregate + final)', () {
    test('small combined facts go straight to a single summary call', () async {
      final mock = _MockLlmClient([
        jsonEncode({'summary': 'アリスは王女で剣士。'}),
      ]);
      final pipeline = LlmSummaryPipeline(llmClient: mock);

      final summary = await pipeline.summarizeFromFacts(
        word: 'アリス',
        perFileFacts: ['- 王女', '- 剣士'],
      );

      expect(summary, 'アリスは王女で剣士。');
      expect(mock.callCount, 1, reason: 'no refinement needed; only final');
    });

    test('combined facts over the chunk size trigger a refinement round',
        () async {
      // Two file-facts of ~30 chars each (combined ~60 > maxChunkSize 40) →
      // a round-2 refinement pass, then the final summary.
      final mock = _MockLlmClient([
        jsonEncode({'facts': '- 短縮1'}),
        jsonEncode({'facts': '- 短縮2'}),
        jsonEncode({'summary': '最終要約。'}),
      ]);
      final pipeline = LlmSummaryPipeline(llmClient: mock, maxChunkSize: 40);

      final events = <AnalysisProgress>[];
      final summary = await pipeline.summarizeFromFacts(
        word: 'アリス',
        perFileFacts: ['- ${'あ' * 28}', '- ${'い' * 28}'],
        onProgress: events.add,
      );

      expect(summary, '最終要約。');
      expect(mock.callCount, greaterThan(1), reason: 'refinement happened');

      final round2 = events
          .whereType<AnalysisExtractingFacts>()
          .where((e) => e.round == 2)
          .toList();
      expect(round2, isNotEmpty,
          reason: 'refinement emits round>=2 fact-extraction events');
      expect(events.last, isA<AnalysisGeneratingFinalSummary>());
    });

    test('empty per-file facts still emit one final-summary event and call',
        () async {
      final mock = _MockLlmClient([
        jsonEncode({'summary': '情報なし。'}),
      ]);
      final pipeline = LlmSummaryPipeline(llmClient: mock);

      final events = <AnalysisProgress>[];
      final summary = await pipeline.summarizeFromFacts(
        word: 'アリス',
        perFileFacts: const [],
        onProgress: events.add,
      );

      expect(summary, '情報なし。');
      expect(mock.callCount, 1);
      expect(events.single, isA<AnalysisGeneratingFinalSummary>());
    });
  });

  // Shared-helper coverage that previously lived in the deleted `generate()`
  // tests. `summarizeFromFacts` exercises the same `_extractFactsRecursive`
  // (recursion depth guard / no-progress termination), `_parseSummaryResponse`
  // (JSON parsing, code-fence stripping, F132 regression) and
  // `_isolatedNotifier` (progress-callback isolation) helpers.
  group('LlmSummaryPipeline.summarizeFromFacts (shared-helper behavior)', () {
    test('recursion depth limit prevents infinite refinement', () async {
      // Combined facts (20ch) exceed maxChunkSize(10) → refinement starts at
      // depth 1. Each round compresses but never fits, so without the
      // maxRecursionDepth(3) guard refinement would never terminate.
      //   depth 1: 20ch → 15ch (progress) → recurse
      //   depth 2: 15ch → 13ch (progress) → recurse
      //   depth 3: >= maxRecursionDepth → return without another call
      // Then the final summary call. Total: 2 extractions + 1 summary.
      final mock = _MockLlmClient([
        jsonEncode({'facts': '- ${'あ' * 13}'}), // 15 chars
        jsonEncode({'facts': '- ${'あ' * 11}'}), // 13 chars
        jsonEncode({'summary': '再帰上限到達の要約。'}),
      ]);
      final pipeline = LlmSummaryPipeline(
        llmClient: mock,
        maxChunkSize: 10,
        maxRecursionDepth: 3,
      );

      final summary = await pipeline.summarizeFromFacts(
        word: 'テスト',
        perFileFacts: ['あ' * 20],
      );

      expect(summary, '再帰上限到達の要約。');
      expect(mock.callCount, 3); // 2 refinement extractions + 1 summary
    });

    test('refinement stops when a round makes no compression progress',
        () async {
      // Combined facts (60ch) exceed maxChunkSize(50) → refinement at depth 1,
      // but the round returns LARGER facts (no progress) so it must stop
      // immediately instead of recursing on the bigger output.
      final mock = _MockLlmClient([
        jsonEncode({'facts': '- ${'あ' * 200}'}),
        jsonEncode({'summary': '圧縮不可の要約。'}),
      ]);
      final pipeline = LlmSummaryPipeline(llmClient: mock, maxChunkSize: 50);

      final summary = await pipeline.summarizeFromFacts(
        word: 'テスト',
        perFileFacts: ['あ' * 60],
      );

      expect(summary, '圧縮不可の要約。');
      expect(mock.callCount, 2); // 1 extraction (no progress) + 1 summary
    });

    test(
        'valid JSON whose summary value is null throws '
        'LlmResponseFormatException (raw JSON is never persisted)', () async {
      // Regression for F132: a CastError must not be swallowed and the raw JSON
      // must never be returned/persisted as the summary.
      final mock = _MockLlmClient([jsonEncode({'summary': null})]);
      final pipeline = LlmSummaryPipeline(llmClient: mock);

      await expectLater(
        pipeline.summarizeFromFacts(word: 'テスト', perFileFacts: const []),
        throwsA(isA<LlmResponseFormatException>()),
      );
    });

    test(
        'valid JSON object missing the summary key throws '
        'LlmResponseFormatException', () async {
      final mock = _MockLlmClient([jsonEncode({'unexpected': 'value'})]);
      final pipeline = LlmSummaryPipeline(llmClient: mock);

      await expectLater(
        pipeline.summarizeFromFacts(word: 'テスト', perFileFacts: const []),
        throwsA(isA<LlmResponseFormatException>()),
      );
    });

    test('falls back to raw text for a non-JSON summary response', () async {
      final mock = _MockLlmClient(['プレーンテキストの要約']);
      final pipeline = LlmSummaryPipeline(llmClient: mock);

      final summary = await pipeline.summarizeFromFacts(
        word: 'テスト',
        perFileFacts: ['- 王女'],
      );

      expect(summary, 'プレーンテキストの要約');
    });

    test('strips a code fence from the summary response', () async {
      final mock = _MockLlmClient([
        '```json\n{"summary": "コードフェンス対応済み。"}\n```',
      ]);
      final pipeline = LlmSummaryPipeline(llmClient: mock);

      final summary = await pipeline.summarizeFromFacts(
        word: 'テスト',
        perFileFacts: ['- 王女'],
      );

      expect(summary, 'コードフェンス対応済み。');
    });

    test('a throwing onProgress callback does not abort summarization',
        () async {
      // A buggy UI callback must NOT break data-layer summarization: the
      // final-summary progress event fires even with no refinement, and its
      // failure is isolated so the summary still completes.
      final mock = _MockLlmClient([jsonEncode({'summary': '隔離成功'})]);
      final pipeline = LlmSummaryPipeline(llmClient: mock);

      final summary = await pipeline.summarizeFromFacts(
        word: 'テスト',
        perFileFacts: ['- 王女'],
        onProgress: (_) => throw StateError('callback boom'),
      );

      expect(summary, '隔離成功');
    });
  });
}
