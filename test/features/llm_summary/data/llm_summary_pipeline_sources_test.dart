import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_pipeline.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_analysis_failure.dart';

/// Records every request and answers by the field the caller asked for.
///
/// A refinement round is answered by [refine] (given the `<facts>` block it
/// was handed); a final summary is answered with a fixed summary.
class _RecordingClient extends LlmClient {
  _RecordingClient({String Function(String facts)? refine})
    : _refine = refine ?? ((_) => '- 縮');

  final String Function(String facts) _refine;
  final List<String> refinementPrompts = [];
  final List<String> summaryPrompts = [];
  final List<String> allPrompts = [];

  @override
  String get modelId => 'test:fake';

  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async {
    allPrompts.add(prompt);
    if (schema?.fieldName == 'summary') {
      summaryPrompts.add(prompt);
      return jsonEncode({'summary': '要約'});
    }
    refinementPrompts.add(prompt);
    return jsonEncode({'facts': _refine(_factsBlock(prompt))});
  }
}

String _factsBlock(String prompt) {
  final start = prompt.indexOf('<facts>\n') + '<facts>\n'.length;
  final end = prompt.indexOf('\n</facts>');
  return prompt.substring(start, end);
}

void main() {
  group('summarizeFromSources', () {
    test('labels every line of a reference source and places it first', () async {
      final client = _RecordingClient();
      final pipeline = LlmSummaryPipeline(llmClient: client);

      await pipeline.summarizeFromSources(
        word: 'アリス',
        ownFacts: const ['- 冒険者になった'],
        referenceFacts: const [
          ReferenceSourceFacts(
            title: '第1部',
            perFileFacts: ['- 王女である\n- 剣が得意', '城で育った'],
          ),
        ],
      );

      expect(client.refinementPrompts, isEmpty);
      final facts = _factsBlock(client.summaryPrompts.single);
      expect(
        facts,
        '- 『第1部』より: 王女である\n'
        '- 『第1部』より: 剣が得意\n'
        '『第1部』より: 城で育った\n'
        '- 冒険者になった',
      );
    });

    test('asks the final summary to prefer this work', () async {
      final client = _RecordingClient();
      final pipeline = LlmSummaryPipeline(llmClient: client);

      await pipeline.summarizeFromSources(
        word: 'アリス',
        ownFacts: const ['- 冒険者'],
        referenceFacts: const [
          ReferenceSourceFacts(title: '第1部', perFileFacts: ['- 王女']),
        ],
      );

      expect(client.summaryPrompts.single, contains('本作の事実を優先'));
    });

    test('reference sources keep the given order', () async {
      final client = _RecordingClient();
      final pipeline = LlmSummaryPipeline(llmClient: client);

      await pipeline.summarizeFromSources(
        word: 'アリス',
        ownFacts: const ['- 本作'],
        referenceFacts: const [
          ReferenceSourceFacts(title: 'A', perFileFacts: ['- a']),
          ReferenceSourceFacts(title: 'B', perFileFacts: ['- b']),
        ],
      );

      expect(
        _factsBlock(client.summaryPrompts.single),
        '- 『A』より: a\n- 『B』より: b\n- 本作',
      );
    });

    test('a large reference source is compressed on its own', () async {
      final client = _RecordingClient();
      final pipeline = LlmSummaryPipeline(
        llmClient: client,
        maxChunkSize: 400,
        maxResponseSize: 100,
      );
      final big = List.generate(3, (i) => '- 祖先の事実$i ${'あ' * 70}');

      await pipeline.summarizeFromSources(
        word: 'アリス',
        ownFacts: const ['- 本作だけの事実'],
        referenceFacts: [ReferenceSourceFacts(title: '第1部', perFileFacts: big)],
      );

      expect(client.refinementPrompts, isNotEmpty);
      for (final prompt in client.refinementPrompts) {
        expect(prompt, isNot(contains('本作だけの事実')));
      }
      expect(
        _factsBlock(client.summaryPrompts.single),
        '- 『第1部』より: 縮\n- 本作だけの事実',
      );
    });

    test('a reference source that fits is not compressed', () async {
      final client = _RecordingClient();
      final pipeline = LlmSummaryPipeline(
        llmClient: client,
        maxChunkSize: 400,
        maxResponseSize: 100,
      );

      await pipeline.summarizeFromSources(
        word: 'アリス',
        ownFacts: const ['- 本作'],
        referenceFacts: const [
          ReferenceSourceFacts(title: '資料', perFileFacts: ['- 短い']),
        ],
      );

      expect(client.refinementPrompts, isEmpty);
      expect(client.allPrompts, hasLength(1));
    });

    test('a reference source without facts contributes nothing', () async {
      final withEmpty = _RecordingClient();
      await LlmSummaryPipeline(llmClient: withEmpty).summarizeFromSources(
        word: 'アリス',
        ownFacts: const ['- 本作'],
        referenceFacts: const [
          ReferenceSourceFacts(title: '空', perFileFacts: ['', '  ']),
        ],
      );
      final plain = _RecordingClient();
      await LlmSummaryPipeline(
        llmClient: plain,
      ).summarizeFromFacts(word: 'アリス', perFileFacts: const ['- 本作']);

      expect(withEmpty.allPrompts, plain.allPrompts);
    });

    test('with no reference sources it matches summarizeFromFacts', () async {
      final own = List.generate(6, (i) => '- 事実$i ${'い' * 60}');
      final viaSources = _RecordingClient();
      await LlmSummaryPipeline(
        llmClient: viaSources,
        maxChunkSize: 200,
        maxResponseSize: 100,
      ).summarizeFromSources(word: 'アリス', ownFacts: own, referenceFacts: const []);
      final viaFacts = _RecordingClient();
      await LlmSummaryPipeline(
        llmClient: viaFacts,
        maxChunkSize: 200,
        maxResponseSize: 100,
      ).summarizeFromFacts(word: 'アリス', perFileFacts: own);

      expect(viaSources.allPrompts, viaFacts.allPrompts);
    });

    test('summarizes when only a reference source has facts', () async {
      final client = _RecordingClient();
      final summary = await LlmSummaryPipeline(llmClient: client)
          .summarizeFromSources(
            word: 'アリス',
            ownFacts: const [],
            referenceFacts: const [
              ReferenceSourceFacts(title: '第1部', perFileFacts: ['- 王女']),
            ],
          );

      expect(summary, '要約');
      expect(_factsBlock(client.summaryPrompts.single), '- 『第1部』より: 王女');
    });

    test('fails with no facts only when every source is empty', () async {
      final client = _RecordingClient();
      await expectLater(
        LlmSummaryPipeline(llmClient: client).summarizeFromSources(
          word: 'アリス',
          ownFacts: const [''],
          referenceFacts: const [
            ReferenceSourceFacts(title: '第1部', perFileFacts: ['']),
          ],
        ),
        throwsA(isA<LlmAnalysisNoFactsFailure>()),
      );
      expect(client.allPrompts, isEmpty);
    });

    test('merged aggregation keeps labels and rounds never step back', () async {
      final client = _RecordingClient();
      final events = <AnalysisProgress>[];
      final pipeline = LlmSummaryPipeline(
        llmClient: client,
        maxChunkSize: 200,
        maxResponseSize: 100,
      );
      final bigAncestor = List.generate(3, (i) => '- 祖先$i ${'う' * 70}');
      final bigOwn = List.generate(3, (i) => '- 本作$i ${'え' * 80}');

      await pipeline.summarizeFromSources(
        word: 'アリス',
        ownFacts: bigOwn,
        referenceFacts: [
          ReferenceSourceFacts(title: '第1部', perFileFacts: bigAncestor),
        ],
        onProgress: events.add,
      );

      final rounds = events
          .whereType<AnalysisExtractingFacts>()
          .map((e) => e.round)
          .toList();
      expect(rounds.first, 2);
      for (var i = 1; i < rounds.length; i++) {
        expect(rounds[i], greaterThanOrEqualTo(rounds[i - 1]));
      }
      expect(rounds.toSet().length, greaterThan(1),
          reason: 'the merged aggregation numbers on from the ancestor one');
      final mergedPrompts = client.refinementPrompts.where(
        (p) => p.contains('本作0'),
      );
      expect(mergedPrompts, isNotEmpty);
      for (final prompt in mergedPrompts) {
        expect(prompt, contains('出典ラベル'));
      }
    });

    test('fitting the window keeps the tail where this work sits', () async {
      // Refinement echoes its input, so it never shrinks and the facts reach
      // the window cut unchanged.
      final client = _RecordingClient(refine: (facts) => facts);
      final pipeline = LlmSummaryPipeline(
        llmClient: client,
        maxChunkSize: 200,
        maxResponseSize: 100,
      );
      final ancestor = List.generate(4, (i) => '- 祖先$i ${'お' * 30}');

      await pipeline.summarizeFromSources(
        word: 'アリス',
        ownFacts: List.generate(3, (i) => '- 本作$i ${'か' * 30}'),
        referenceFacts: [
          ReferenceSourceFacts(title: '資料', perFileFacts: [ancestor.join('\n')]),
        ],
      );

      final facts = _factsBlock(client.summaryPrompts.single);
      expect(facts.length, lessThanOrEqualTo(200));
      expect(facts, contains('本作2'));
      expect(facts, isNot(contains('祖先0')));
      for (final line in facts.split('\n')) {
        if (line.contains('祖先')) expect(line, contains('『資料』より:'));
      }
    });
  });
}
