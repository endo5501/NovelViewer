import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_prompt_builder.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_pipeline.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_data_db_fixture.dart';

/// Counts extraction calls and declares whatever budget the test asks for.
class _BudgetedClient extends LlmClient {
  _BudgetedClient({required this.budget});

  final int budget;

  int extractionCalls = 0;
  int summaryCalls = 0;

  @override
  int get maxChunkSize => budget;

  @override
  String get modelId => 'test:fake';

  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async {
    if (schema?.fieldName == 'summary') {
      summaryCalls++;
      return jsonEncode({'summary': 'まとめ'});
    }
    extractionCalls++;
    return jsonEncode({'facts': '- 事実'});
  }
}

/// Declares a window and a response budget that differ, answers Stage-1
/// with facts of a set length, and keeps every refinement prompt it is sent,
/// so a test can make aggregation happen and see how it was sized.
class _TwoBudgetClient extends LlmClient {
  _TwoBudgetClient({
    required this.window,
    required this.response,
    this.factsLength = 4,
  });

  final int window;
  final int response;
  final int factsLength;

  final List<String> refinementPrompts = [];
  int extractionCalls = 0;

  @override
  int get maxChunkSize => window;

  @override
  int get maxResponseSize => response;

  @override
  String get modelId => 'test:fake';

  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async {
    if (schema?.fieldName == 'summary') {
      return jsonEncode({'summary': 'まとめ'});
    }
    if (prompt.contains('<facts>')) {
      refinementPrompts.add(prompt);
      return jsonEncode({'facts': '- 統合'});
    }
    extractionCalls++;
    return jsonEncode({'facts': '- ${'事' * factsLength}'});
  }
}

void main() {
  group('aggregation is sized by the response budget', () {
    /// Six files' facts of 900 characters: 5400 in all, over a 4000 window.
    List<String> facts() => List.generate(6, (i) => '- ${'事' * 897}$i');

    LlmSummaryPipeline pipelineFor(_TwoBudgetClient client) =>
        LlmSummaryPipeline(
          llmClient: client,
          maxChunkSize: client.maxChunkSize,
          maxResponseSize: client.maxResponseSize,
        );

    test('each aggregation chunk fits the response budget', () async {
      // At the 4000 window the six would pack into two chunks, and each
      // chunk's answer would be asked to hold up to 3600 characters of facts.
      final client = _TwoBudgetClient(window: 4000, response: 1000);

      await pipelineFor(
        client,
      ).summarizeFromFacts(word: 'アリス', perFileFacts: facts());

      expect(client.refinementPrompts, hasLength(6));
    });

    test('aggregation uses the refinement prompt, not extraction', () async {
      final client = _TwoBudgetClient(window: 4000, response: 1000);

      await pipelineFor(
        client,
      ).summarizeFromFacts(word: 'アリス', perFileFacts: facts());

      expect(client.refinementPrompts, isNotEmpty);
      expect(client.extractionCalls, 0);
    });

    test('the refinement bound follows the response budget', () async {
      final client = _TwoBudgetClient(window: 4000, response: 1000);
      final bound = LlmPromptBuilder.refinementBound(1000);

      await pipelineFor(
        client,
      ).summarizeFromFacts(word: 'アリス', perFileFacts: facts());

      expect(client.refinementPrompts, isNotEmpty);
      expect(client.refinementPrompts, everyElement(contains('$bound文字以内')));
    });

    test('a pipeline given no response budget takes the client\'s', () async {
      // Handed only the window, the pipeline must still size aggregation by
      // what the client says it can return, not fall back to the window.
      final client = _TwoBudgetClient(window: 4000, response: 1000);
      final pipeline = LlmSummaryPipeline(
        llmClient: client,
        maxChunkSize: client.maxChunkSize,
      );

      expect(pipeline.maxResponseSize, 1000);
    });

    test('the response budget never exceeds the window', () async {
      // A client that declares none answers with its own window, which can
      // be larger than the window the pipeline was given.
      final client = _BudgetedClient(budget: 4000);
      final pipeline = LlmSummaryPipeline(llmClient: client, maxChunkSize: 40);

      expect(pipeline.maxResponseSize, 40);
    });

    test('Stage-1 keeps the window, not the response budget', () async {
      // Stage-1 compresses prose into a list, so its answer sits well inside
      // the response budget; sizing it by that would multiply the requests.
      final client = _TwoBudgetClient(window: 4000, response: 1000);

      await pipelineFor(client).extractFileFacts(
        word: 'アリス',
        contexts: List.generate(12, (i) => 'アリス${'あ' * 994}$i'),
      );

      expect(client.extractionCalls, 3);
    });
  });

  group('the pipeline chunks to the budget it was given', () {
    /// Twelve context entries of a thousand characters each.
    List<String> contexts() => List.generate(12, (i) => 'アリス${'あ' * 994}$i');

    test('a budget of 4000 keeps the behaviour it had before', () async {
      final client = _BudgetedClient(budget: 4000);
      final pipeline = LlmSummaryPipeline(
        llmClient: client,
        maxChunkSize: client.maxChunkSize,
      );

      await pipeline.extractFileFacts(word: 'アリス', contexts: contexts());

      expect(client.extractionCalls, 3);
    });

    test('halving the budget about doubles the chunks', () async {
      final client = _BudgetedClient(budget: 2000);
      final pipeline = LlmSummaryPipeline(
        llmClient: client,
        maxChunkSize: client.maxChunkSize,
      );

      await pipeline.extractFileFacts(word: 'アリス', contexts: contexts());

      expect(client.extractionCalls, 6);
    });

    test('a smaller budget lowers the aggregation threshold', () async {
      final client = _BudgetedClient(budget: 2000);
      final pipeline = LlmSummaryPipeline(
        llmClient: client,
        maxChunkSize: client.maxChunkSize,
      );

      // Three thousand characters of facts: within 4000, over 2000. At the
      // smaller budget this has to be aggregated before it can be summarised.
      await pipeline.summarizeFromFacts(
        word: 'アリス',
        perFileFacts: ['- ${'事' * 2998}'],
      );

      expect(
        client.extractionCalls,
        greaterThan(0),
        reason: 'recursive aggregation should have run',
      );
    });

    test(
      'the same facts go straight to the summary at the larger budget',
      () async {
        final client = _BudgetedClient(budget: 4000);
        final pipeline = LlmSummaryPipeline(
          llmClient: client,
          maxChunkSize: client.maxChunkSize,
        );

        await pipeline.summarizeFromFacts(
          word: 'アリス',
          perFileFacts: ['- ${'事' * 2998}'],
        );

        expect(client.extractionCalls, 0);
        expect(client.summaryCalls, 1);
      },
    );
  });

  group('the service takes the budget from its client', () {
    late Database db;
    late Directory tempDir;
    late LlmSummaryRepository repository;
    late FactCacheRepository factCache;

    setUp(() async {
      sqfliteFfiInit();
      db = await openInMemoryNovelDataDb();
      repository = LlmSummaryRepository(db);
      factCache = FactCacheRepository(db);
      tempDir = await Directory.systemTemp.createTemp('llm_budget_test_');
      // Lines short enough that a context slice fits either budget: what
      // differs between the budgets is how many slices are packed together,
      // which is the thing under test. Slices too large for both would each
      // take a chunk of their own and hide the difference.
      await File(
        '${tempDir.path}/001_ch.txt',
      ).writeAsString(List.generate(10, (i) => 'アリス${'あ' * 144}$i').join('\n'));
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    Future<int> extractionCallsWith(int budget) async {
      final client = _BudgetedClient(budget: budget);
      await LlmSummaryService(
        llmClient: client,
        repository: repository,
        factCacheRepository: factCache,
        searchService: TextSearchService(),
      ).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 1,
      );
      return client.extractionCalls;
    }

    test('aggregation is sized by the client\'s response budget', () async {
      // Six files whose facts come back at 900 characters each: 5400 in all,
      // over the 4000 window, so aggregation runs. Handed the client's
      // response budget, the service splits it into six rounds; handed only
      // the window, it would pack them into two.
      for (var i = 2; i <= 6; i++) {
        await File(
          '${tempDir.path}/00${i}_ch.txt',
        ).writeAsString('アリス${'い' * 20}$i');
      }
      final client = _TwoBudgetClient(
        window: 4000,
        response: 1000,
        factsLength: 898,
      );

      await LlmSummaryService(
        llmClient: client,
        repository: repository,
        factCacheRepository: factCache,
        searchService: TextSearchService(),
      ).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 6,
      );

      // Each round carries at most the response budget. Counting rounds would
      // tie this to the fixture: the shared first file matches ten times, and
      // its facts exceed the budget on their own, so they are split too.
      expect(client.refinementPrompts.length, greaterThan(2));
      for (final prompt in client.refinementPrompts) {
        final facts = RegExp(
          r'<facts>\n([\s\S]*)\n</facts>',
        ).firstMatch(prompt)!.group(1)!;
        expect(facts.length, lessThanOrEqualTo(1000));
      }
    });

    test('a client with a smaller budget is asked more times', () async {
      final atFourThousand = await extractionCallsWith(4000);
      // The first run filled the cache; clear it so the second run extracts.
      await factCache.invalidateWord(
        word: 'アリス',
        modelId: 'test:fake',
        notNewerThan: DateTime.now().toUtc(),
      );
      final atTwoThousand = await extractionCallsWith(2000);

      expect(atFourThousand, greaterThan(0));
      expect(atTwoThousand, greaterThan(atFourThousand));
    });
  });
}
