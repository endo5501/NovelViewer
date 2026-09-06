import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_format_exception.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_pipeline.dart';

class _FixedLlmClient extends LlmClient {
  _FixedLlmClient(this.response);

  final String response;

  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async =>
      response;
}

void main() {
  group('extractFileFactsDetailed', () {
    test('reports a structured decode for a well-formed response', () async {
      final pipeline = LlmSummaryPipeline(
        llmClient: _FixedLlmClient(jsonEncode({'facts': '- 王国の王女'})),
      );

      final result = await pipeline.extractFileFactsDetailed(
        word: 'アリス',
        contexts: ['アリスは王国の王女。'],
      );

      expect(result.facts, '- 王国の王女');
      expect(result.isStructured, isTrue);
    });

    test('reports a fallback when the response is not JSON', () async {
      final pipeline = LlmSummaryPipeline(
        llmClient: _FixedLlmClient('- 素のテキストで返ってきた事実'),
      );

      final result = await pipeline.extractFileFactsDetailed(
        word: 'アリス',
        contexts: ['アリスは王国の王女。'],
      );

      expect(result.facts, '- 素のテキストで返ってきた事実');
      expect(result.isStructured, isFalse);
    });

    test(
      'reports a fallback when a broken JSON fragment is returned',
      () async {
        // The shape observed in production: a string value containing an
        // unescaped quote, which fails jsonDecode.
        const broken = '{"facts": "- "ダプラ" は見習いの身分である。"}';
        final pipeline = LlmSummaryPipeline(llmClient: _FixedLlmClient(broken));

        final result = await pipeline.extractFileFactsDetailed(
          word: 'ダプラ',
          contexts: ['ダプラという身分がある。'],
        );

        expect(result.facts, broken);
        expect(result.isStructured, isFalse);
      },
    );

    test('a file whose chunks all decode cleanly stays structured', () async {
      final pipeline = LlmSummaryPipeline(
        llmClient: _FixedLlmClient(jsonEncode({'facts': '- 事実'})),
        maxChunkSize: 50,
      );

      final result = await pipeline.extractFileFactsDetailed(
        word: 'アリス',
        contexts: ['あ' * 60, 'い' * 60],
      );

      expect(result.isStructured, isTrue);
    });

    test('one fallback chunk makes the whole file unstructured', () async {
      var callCount = 0;
      final pipeline = LlmSummaryPipeline(
        llmClient: _AlternatingLlmClient(() {
          callCount++;
          return callCount == 1 ? jsonEncode({'facts': '- 事実'}) : '- 素のテキスト';
        }),
        maxChunkSize: 50,
      );

      final result = await pipeline.extractFileFactsDetailed(
        word: 'アリス',
        contexts: ['あ' * 60, 'い' * 60],
      );

      expect(result.isStructured, isFalse);
    });

    test(
      'empty contexts yield an empty, structured result with no LLM call',
      () async {
        var callCount = 0;
        final pipeline = LlmSummaryPipeline(
          llmClient: _AlternatingLlmClient(() {
            callCount++;
            return jsonEncode({'facts': '- 事実'});
          }),
        );

        final result = await pipeline.extractFileFactsDetailed(
          word: 'アリス',
          contexts: [],
        );

        expect(result.facts, '');
        expect(result.isStructured, isTrue);
        expect(callCount, 0);
      },
    );

    test('a string array facts value is joined with newlines and stays '
        'structured', () async {
      // MLX runners ignore the requested `format`, so a capable model returns
      // {"facts": [...]} even though a single string was requested.
      final pipeline = LlmSummaryPipeline(
        llmClient: _FixedLlmClient(
          jsonEncode({
            'facts': ['王国の王女である。', '剣術の達人である。'],
          }),
        ),
      );

      final result = await pipeline.extractFileFactsDetailed(
        word: 'アリス',
        contexts: ['アリスは王国の王女。'],
      );

      expect(result.facts, '王国の王女である。\n剣術の達人である。');
      expect(result.isStructured, isTrue);
    });

    test('array elements already carrying a bullet prefix are not '
        'double-prefixed', () async {
      final pipeline = LlmSummaryPipeline(
        llmClient: _FixedLlmClient(
          jsonEncode({
            'facts': ['- 王国の王女である。', '- 剣術の達人である。'],
          }),
        ),
      );

      final result = await pipeline.extractFileFactsDetailed(
        word: 'アリス',
        contexts: ['アリスは王国の王女。'],
      );

      expect(result.facts, '- 王国の王女である。\n- 剣術の達人である。');
      expect(result.isStructured, isTrue);
    });
  });

  group('summarizeFromFacts array normalization', () {
    test('a string array summary value is joined with newlines', () async {
      final pipeline = LlmSummaryPipeline(
        llmClient: _FixedLlmClient(
          jsonEncode({
            'summary': ['アリスは王女。', '剣術に秀でる。'],
          }),
        ),
      );

      final summary = await pipeline.summarizeFromFacts(
        word: 'アリス',
        perFileFacts: ['- 王女', '- 剣士'],
      );

      expect(summary, 'アリスは王女。\n剣術に秀でる。');
    });
  });

  group('array values that are not normalizable are rejected', () {
    test(
      'an empty array throws LlmResponseFormatException and logs WARNING',
      () async {
        final records = <LogRecord>[];
        final sub = Logger.root.onRecord.listen(records.add);
        addTearDown(sub.cancel);

        final pipeline = LlmSummaryPipeline(
          llmClient: _FixedLlmClient(jsonEncode({'summary': <String>[]})),
        );

        await expectLater(
          pipeline.summarizeFromFacts(
            word: 'アリス',
            perFileFacts: const ['- 王女'],
          ),
          throwsA(isA<LlmResponseFormatException>()),
        );
        expect(records.any((r) => r.level == Level.WARNING), isTrue);
      },
    );

    test('an array containing a non-string element throws '
        'LlmResponseFormatException and logs WARNING', () async {
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);

      final pipeline = LlmSummaryPipeline(
        llmClient: _FixedLlmClient('{"summary": ["ok", 123]}'),
      );

      await expectLater(
        pipeline.summarizeFromFacts(word: 'アリス', perFileFacts: const ['- 王女']),
        throwsA(isA<LlmResponseFormatException>()),
      );
      expect(records.any((r) => r.level == Level.WARNING), isTrue);
    });
  });
}

class _AlternatingLlmClient extends LlmClient {
  _AlternatingLlmClient(this.next);

  final String Function() next;

  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async =>
      next();
}
