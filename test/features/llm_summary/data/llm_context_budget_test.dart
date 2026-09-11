import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
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
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async {
    if (schema?.fieldName == 'summary') {
      summaryCalls++;
      return jsonEncode({'summary': 'まとめ'});
    }
    extractionCalls++;
    return jsonEncode({'facts': '- 事実'});
  }
}

void main() {
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

    test('a client with a smaller budget is asked more times', () async {
      final atFourThousand = await extractionCallsWith(4000);
      // The first run filled the cache; clear it so the second run extracts.
      await factCache.invalidateWord(
        word: 'アリス',
        notNewerThan: DateTime.now().toUtc(),
      );
      final atTwoThousand = await extractionCallsWith(2000);

      expect(atFourThousand, greaterThan(0));
      expect(atTwoThousand, greaterThan(atFourThousand));
    });
  });
}
