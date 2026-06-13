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
  group('LlmSummaryPipeline', () {
    test('single chunk produces summary in 2 calls (extract + summarize)',
        () async {
      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 王国の王女'}),
        jsonEncode({'summary': 'アリスは王国の王女。'}),
      ]);

      final pipeline = LlmSummaryPipeline(llmClient: mockClient);
      final result = await pipeline.generate(
        word: 'アリス',
        contexts: ['アリスは王国の王女として登場した。'],
      );

      expect(result, 'アリスは王国の王女。');
      expect(mockClient.callCount, 2);
    });

    test('multiple chunks produces summary with multiple extract calls',
        () async {
      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 王国の王女'}),
        jsonEncode({'facts': '- 剣術の達人'}),
        jsonEncode({'summary': 'アリスは王国の王女で剣術の達人。'}),
      ]);

      final pipeline = LlmSummaryPipeline(
        llmClient: mockClient,
        maxChunkSize: 15,
      );

      final result = await pipeline.generate(
        word: 'アリス',
        contexts: [
          'アリスは王国の王女として登場した。',
          'アリスは剣術の達人であった。',
        ],
      );

      expect(result, 'アリスは王国の王女で剣術の達人。');
      expect(mockClient.callCount, 3);
    });

    test('recursive aggregation when facts exceed chunk size', () async {
      // Contexts: 3 entries of ~60 chars each (total ~180 > maxChunkSize 100)
      // Stage 1: 3 chunks → 3 fact extractions, each returns ~40 chars
      //   Combined ~120 chars > 100, but shorter than input → recurse
      // Stage 2: 2 chunks → re-aggregate, returns short facts
      //   Combined fits in 100 → proceed to summary
      final mediumFacts = '- ${'あ' * 18}';  // ~20 chars each
      const shortFacts = '- 短い事実';        // ~6 chars

      final mockClient = _MockLlmClient([
        // Stage 1: extract from 3 chunks
        jsonEncode({'facts': mediumFacts}),
        jsonEncode({'facts': mediumFacts}),
        jsonEncode({'facts': mediumFacts}),
        // Stage 2: re-aggregate from 2 chunks (60 chars > 50 per chunk)
        jsonEncode({'facts': shortFacts}),
        jsonEncode({'facts': shortFacts}),
        // Final summary
        jsonEncode({'summary': '最終要約。'}),
      ]);

      final pipeline = LlmSummaryPipeline(
        llmClient: mockClient,
        maxChunkSize: 50,
      );

      final contexts =
          List.generate(3, (i) => '${'テスト' * 10}コンテキスト$i');

      final result = await pipeline.generate(
        word: 'テスト',
        contexts: contexts,
      );

      expect(result, '最終要約。');
      // More than 2 calls means recursion happened
      expect(mockClient.callCount, greaterThan(3));
    });

    test('recursion limit prevents infinite loop', () async {
      // Each round compresses slightly but never fits in maxChunkSize(10)
      // depth 0: input 20 chars → output 15 chars (progress). 15 > 10 → recurse
      // depth 1: input 15 chars → output 13 chars (progress). 13 > 10 → recurse
      // depth 2: input 13 chars → output 12 chars (progress). 12 > 10 → recurse
      // depth 3: >= maxRecursionDepth(3) → return without more calls
      // Then final summary call

      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- ${'あ' * 13}'}), // 15 chars
        jsonEncode({'facts': '- ${'あ' * 11}'}), // 13 chars
        jsonEncode({'facts': '- ${'あ' * 10}'}), // 12 chars
        jsonEncode({'summary': '再帰上限到達の要約。'}),
      ]);

      final pipeline = LlmSummaryPipeline(
        llmClient: mockClient,
        maxChunkSize: 10,
        maxRecursionDepth: 3,
      );

      final result = await pipeline.generate(
        word: 'テスト',
        contexts: ['あ' * 20],
      );

      expect(result, '再帰上限到達の要約。');
      expect(mockClient.callCount, 4); // 3 extractions + 1 summary
    });

    test('early termination when no compression progress', () async {
      // LLM returns facts that are larger than input → no progress → stop
      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- ${'あ' * 200}'}),
        jsonEncode({'summary': '圧縮不可の要約。'}),
      ]);

      final pipeline = LlmSummaryPipeline(
        llmClient: mockClient,
        maxChunkSize: 50,
      );

      final result = await pipeline.generate(
        word: 'テスト',
        contexts: ['短い入力'],
      );

      expect(result, '圧縮不可の要約。');
      // Only 1 extraction + 1 summary (no recursion due to no progress)
      expect(mockClient.callCount, 2);
    });

    test('handles empty contexts', () async {
      final mockClient = _MockLlmClient([
        jsonEncode({'summary': '情報なし。'}),
      ]);

      final pipeline = LlmSummaryPipeline(llmClient: mockClient);
      final result = await pipeline.generate(
        word: 'アリス',
        contexts: [],
      );

      expect(result, '情報なし。');
      expect(mockClient.callCount, 1);
    });

    test('falls back to raw text for non-JSON response', () async {
      final mockClient = _MockLlmClient([
        '- 生の事実テキスト',
        'プレーンテキストの要約',
      ]);

      final pipeline = LlmSummaryPipeline(llmClient: mockClient);
      final result = await pipeline.generate(
        word: 'テスト',
        contexts: ['テストコンテキスト'],
      );

      expect(result, 'プレーンテキストの要約');
    });

    test(
        'valid JSON whose summary value is null throws '
        'LlmResponseFormatException (raw JSON is never persisted)', () async {
      // Regression for F132: previously the CastError from `as String` was
      // swallowed and the raw JSON string was returned/persisted as summary.
      final mockClient = _MockLlmClient([
        jsonEncode({'summary': null}),
      ]);

      final pipeline = LlmSummaryPipeline(llmClient: mockClient);

      await expectLater(
        pipeline.generate(word: 'テスト', contexts: []),
        throwsA(isA<LlmResponseFormatException>()),
      );
    });

    test(
        'valid JSON object missing the summary key throws '
        'LlmResponseFormatException', () async {
      final mockClient = _MockLlmClient([
        jsonEncode({'unexpected': 'value'}),
      ]);

      final pipeline = LlmSummaryPipeline(llmClient: mockClient);

      await expectLater(
        pipeline.generate(word: 'テスト', contexts: []),
        throwsA(isA<LlmResponseFormatException>()),
      );
    });

    test('strips code fence from LLM response', () async {
      final mockClient = _MockLlmClient([
        '```json\n{"facts": "- コードフェンス付き事実"}\n```',
        '```json\n{"summary": "コードフェンス対応済み。"}\n```',
      ]);

      final pipeline = LlmSummaryPipeline(llmClient: mockClient);
      final result = await pipeline.generate(
        word: 'テスト',
        contexts: ['テストコンテキスト'],
      );

      expect(result, 'コードフェンス対応済み。');
    });
  });

  group('LlmSummaryPipeline progress notifications', () {
    test('initial fact extraction emits one event per chunk with round=1',
        () async {
      // 2 contexts, small maxChunkSize → 2 extraction chunks + 1 final summary
      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 事実1'}),
        jsonEncode({'facts': '- 事実2'}),
        jsonEncode({'summary': 'まとめ'}),
      ]);

      final pipeline = LlmSummaryPipeline(
        llmClient: mockClient,
        maxChunkSize: 15,
      );

      final events = <AnalysisProgress>[];
      await pipeline.generate(
        word: 'テスト',
        contexts: [
          'コンテキスト一つめ',
          'コンテキスト二つめ',
        ],
        onProgress: events.add,
      );

      // Filter the extracting-facts events of round 1
      final round1Events = events
          .whereType<AnalysisExtractingFacts>()
          .where((e) => e.round == 1)
          .toList();

      expect(round1Events.length, 2);
      expect(round1Events[0].current, 1);
      expect(round1Events[0].total, 2);
      expect(round1Events[1].current, 2);
      expect(round1Events[1].total, 2);
    });

    test('recursive refinement increments round and resets current', () async {
      // Reuse the recursion fixture from the existing recursion test.
      final mediumFacts = '- ${'あ' * 18}';
      const shortFacts = '- 短い事実';

      final mockClient = _MockLlmClient([
        jsonEncode({'facts': mediumFacts}),
        jsonEncode({'facts': mediumFacts}),
        jsonEncode({'facts': mediumFacts}),
        jsonEncode({'facts': shortFacts}),
        jsonEncode({'facts': shortFacts}),
        jsonEncode({'summary': '最終要約。'}),
      ]);

      final pipeline = LlmSummaryPipeline(
        llmClient: mockClient,
        maxChunkSize: 50,
      );

      final contexts =
          List.generate(3, (i) => '${'テスト' * 10}コンテキスト$i');

      final events = <AnalysisProgress>[];
      await pipeline.generate(
        word: 'テスト',
        contexts: contexts,
        onProgress: events.add,
      );

      // Round 1 events
      final round1 = events
          .whereType<AnalysisExtractingFacts>()
          .where((e) => e.round == 1)
          .toList();
      expect(round1.length, 3);
      expect(round1.map((e) => e.current), [1, 2, 3]);
      expect(round1.every((e) => e.total == 3), isTrue);

      // Round 2 (refinement) events
      final round2 = events
          .whereType<AnalysisExtractingFacts>()
          .where((e) => e.round == 2)
          .toList();
      expect(round2.length, 2);
      expect(round2.map((e) => e.current), [1, 2]);
      expect(round2.every((e) => e.total == 2), isTrue);

      // Round 2 must come after all round-1 events
      final round1LastIndex =
          events.lastIndexWhere((e) => e is AnalysisExtractingFacts && e.round == 1);
      final round2FirstIndex =
          events.indexWhere((e) => e is AnalysisExtractingFacts && e.round == 2);
      expect(round2FirstIndex, greaterThan(round1LastIndex));
    });

    test('final summary event fires exactly once before the final LLM call',
        () async {
      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 事実'}),
        jsonEncode({'summary': 'まとめ'}),
      ]);

      final pipeline = LlmSummaryPipeline(llmClient: mockClient);

      final events = <AnalysisProgress>[];
      await pipeline.generate(
        word: 'テスト',
        contexts: ['短いコンテキスト'],
        onProgress: events.add,
      );

      final finals = events.whereType<AnalysisGeneratingFinalSummary>().toList();
      expect(finals.length, 1);
      // Final event must be the very last event in the stream
      expect(events.last, isA<AnalysisGeneratingFinalSummary>());
    });

    test('empty contexts still emit the final summary event', () async {
      final mockClient = _MockLlmClient([
        jsonEncode({'summary': '情報なし。'}),
      ]);

      final pipeline = LlmSummaryPipeline(llmClient: mockClient);

      final events = <AnalysisProgress>[];
      await pipeline.generate(
        word: 'テスト',
        contexts: [],
        onProgress: events.add,
      );

      expect(events.length, 1);
      expect(events.single, isA<AnalysisGeneratingFinalSummary>());
    });

    test('omitting onProgress preserves existing behavior', () async {
      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 事実'}),
        jsonEncode({'summary': 'プログレス無しでも動く'}),
      ]);

      final pipeline = LlmSummaryPipeline(llmClient: mockClient);
      final result = await pipeline.generate(
        word: 'テスト',
        contexts: ['コンテキスト'],
      );

      expect(result, 'プログレス無しでも動く');
      expect(mockClient.callCount, 2);
    });

    test('throwing onProgress does not abort the pipeline', () async {
      // A UI callback throwing must NOT break data-layer generation: the
      // pipeline isolates progress-callback failures so the summary still
      // completes and the LLM tokens already consumed are not wasted.
      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 事実'}),
        jsonEncode({'summary': '隔離成功'}),
      ]);

      final pipeline = LlmSummaryPipeline(llmClient: mockClient);
      final result = await pipeline.generate(
        word: 'テスト',
        contexts: ['コンテキスト'],
        onProgress: (_) {
          throw StateError('callback boom');
        },
      );

      expect(result, '隔離成功');
      expect(mockClient.callCount, 2);
    });
  });
}
