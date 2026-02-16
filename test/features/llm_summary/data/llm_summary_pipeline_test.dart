import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_pipeline.dart';

class _MockLlmClient implements LlmClient {
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
}
