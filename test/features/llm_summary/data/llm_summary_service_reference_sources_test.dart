import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:novel_viewer/shared/utils/content_hash.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_data_db_fixture.dart';

/// Answers extraction requests with the text it was handed (so a test can
/// tell which file produced which fact) and the final summary with a fixed
/// string. Extraction requests whose context contains any of [failOn] throw.
class _EchoClient extends LlmClient {
  _EchoClient({this.failOn = const []});

  final List<String> failOn;
  final List<String> extractionPrompts = [];
  final List<String> summaryPrompts = [];

  @override
  String get modelId => 'test:fake';

  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async {
    if (schema?.fieldName == 'summary') {
      summaryPrompts.add(prompt);
      return jsonEncode({'summary': '要約'});
    }
    extractionPrompts.add(prompt);
    final context = _between(prompt, '<context>\n', '\n</context>');
    if (failOn.any(context.contains)) throw const SocketException('down');
    return jsonEncode({'facts': '- ${context.split('\n').first}'});
  }
}

String _between(String s, String start, String end) {
  final i = s.indexOf(start);
  if (i < 0) return '';
  final from = i + start.length;
  return s.substring(from, s.indexOf(end, from));
}

void main() {
  late Database ownDb;
  late Database ancestorDb;
  late Directory ownDir;
  late Directory ancestorDir;

  setUp(() async {
    sqfliteFfiInit();
    ownDb = await openInMemoryNovelDataDb();
    ancestorDb = await openInMemoryNovelDataDb();
    ownDir = await Directory.systemTemp.createTemp('ref_service_own_');
    ancestorDir = await Directory.systemTemp.createTemp('ref_service_anc_');
  });

  tearDown(() async {
    await ownDb.close();
    await ancestorDb.close();
    await ownDir.delete(recursive: true);
    await ancestorDir.delete(recursive: true);
  });

  void write(Directory dir, String name, String content) =>
      File(p.join(dir.path, name)).writeAsStringSync(content);

  LlmSummaryService service(LlmClient client) => LlmSummaryService(
    llmClient: client,
    repository: LlmSummaryRepository(ownDb),
    factCacheRepository: FactCacheRepository(ownDb),
    searchService: TextSearchService(),
  );

  ReferenceSourceScope ancestor({String title = '第1部'}) => ReferenceSourceScope(
    folderName: 'narou_p1',
    title: title,
    folderPath: ancestorDir.path,
    factCacheRepository: FactCacheRepository(ancestorDb),
  );

  group('evidence scope', () {
    test('whole scope reads every ancestor file containing the word', () async {
      write(ownDir, '001.txt', '本作でアリスが旅に出る。');
      write(ancestorDir, '001.txt', '祖先一話でアリスが生まれる。');
      write(ancestorDir, '050.txt', '祖先五十話でアリスが王位を継ぐ。');
      write(ancestorDir, '051.txt', '関係のない話。');
      final client = _EchoClient();

      await service(client).generateSummary(
        directoryPath: ownDir.path,
        word: 'アリス',
        coveredUpToEpisode: 1,
        referenceSources: [ancestor()],
      );

      final extracted = client.extractionPrompts.join('\n');
      expect(extracted, contains('本作でアリスが旅に出る'));
      expect(extracted, contains('祖先一話'));
      expect(
        extracted,
        contains('祖先五十話'),
        reason: 'the upper bound applies to this work only',
      );
      expect(extracted, isNot(contains('関係のない話')));
      expect(client.summaryPrompts.single, contains('『第1部』より:'));
    });

    test('first-occurrence scope reads only the ancestor\'s first file', () async {
      write(ownDir, '001.txt', '本作でアリスが旅に出る。');
      write(ancestorDir, '003.txt', '祖先三話でアリスが登場。');
      write(ancestorDir, '020.txt', '祖先二十話でアリスが再登場。');
      final client = _EchoClient();

      await service(client).generateSummary(
        directoryPath: ownDir.path,
        word: 'アリス',
        coveredUpToEpisode: 1,
        referenceSources: [ancestor()],
        referenceScope: ReferenceScope.firstOccurrence,
      );

      final extracted = client.extractionPrompts.join('\n');
      expect(extracted, contains('祖先三話'));
      expect(extracted, isNot(contains('祖先二十話')));
    });

    test('an ancestor without the word contributes nothing', () async {
      write(ownDir, '001.txt', '本作でアリスが旅に出る。');
      write(ancestorDir, '001.txt', '別の人物の話。');
      final client = _EchoClient();

      await service(client).generateSummary(
        directoryPath: ownDir.path,
        word: 'アリス',
        coveredUpToEpisode: 1,
        referenceSources: [ancestor()],
        referenceScope: ReferenceScope.firstOccurrence,
      );

      expect(client.extractionPrompts, hasLength(1));
      expect(client.summaryPrompts.single, isNot(contains('より:')));
    });
  });

  group('fact cache placement', () {
    test('ancestor facts are cached in the ancestor\'s own database', () async {
      write(ownDir, '001.txt', '本作でアリスが旅に出る。');
      write(ancestorDir, '003.txt', '祖先三話でアリスが登場。');

      await service(_EchoClient()).generateSummary(
        directoryPath: ownDir.path,
        word: 'アリス',
        coveredUpToEpisode: 1,
        referenceSources: [ancestor()],
      );

      final ancestorRows = await FactCacheRepository(
        ancestorDb,
      ).findForWord(word: 'アリス');
      expect(ancestorRows.map((r) => r.fileName), ['003.txt']);
      final ownRows = await FactCacheRepository(ownDb).findForWord(
        word: 'アリス',
      );
      expect(ownRows.map((r) => r.fileName), ['001.txt']);
    });

    test('a sibling work reuses the ancestor\'s cached facts', () async {
      write(ownDir, '001.txt', '本作でアリスが旅に出る。');
      const ancestorText = '祖先三話でアリスが登場。';
      write(ancestorDir, '003.txt', ancestorText);
      await FactCacheRepository(ancestorDb).upsert(
        word: 'アリス',
        fileName: '003.txt',
        facts: '- 兄弟作品で抽出済み',
        contentHash: computeContentHash(ancestorText),
        promptVersion: FactCacheRepository.currentPromptVersion,
        modelId: 'test:fake',
      );
      final client = _EchoClient();

      await service(client).generateSummary(
        directoryPath: ownDir.path,
        word: 'アリス',
        coveredUpToEpisode: 1,
        referenceSources: [ancestor()],
      );

      expect(client.extractionPrompts.join(), isNot(contains('祖先三話')));
      expect(client.summaryPrompts.single, contains('兄弟作品で抽出済み'));
    });
  });

  group('progress and failures across sources', () {
    test('the extraction total counts misses in every source', () async {
      write(ownDir, '001.txt', 'アリス本作一。');
      write(ownDir, '002.txt', 'アリス本作二。');
      write(ancestorDir, '001.txt', 'アリス祖先一。');
      write(ancestorDir, '002.txt', 'アリス祖先二。');
      write(ancestorDir, '003.txt', 'アリス祖先三。');
      final events = <AnalysisProgress>[];

      await service(_EchoClient()).generateSummary(
        directoryPath: ownDir.path,
        word: 'アリス',
        coveredUpToEpisode: 2,
        referenceSources: [ancestor()],
        onProgress: events.add,
      );

      final round1 = events
          .whereType<AnalysisExtractingFacts>()
          .where((e) => e.round == 1)
          .toList();
      expect(round1.map((e) => e.total).toSet(), {5});
      expect(round1.last.current, 5);
    });

    test('an ancestor file failure is a partial failure and saves nothing', () async {
      write(ownDir, '001.txt', 'アリス本作一。');
      write(ancestorDir, '001.txt', 'アリス祖先一。');

      await expectLater(
        service(_EchoClient(failOn: ['祖先一'])).generateSummary(
          directoryPath: ownDir.path,
          word: 'アリス',
          coveredUpToEpisode: 1,
          referenceSources: [ancestor()],
        ),
        throwsA(
          isA<LlmAnalysisPartialFailure>().having(
            (f) => f.failedFileCount,
            'failedFileCount',
            1,
          ),
        ),
      );
      expect(await LlmSummaryRepository(ownDb).findAll(), isEmpty);
    });

    test('consecutive failures are counted across sources', () async {
      write(ownDir, '001.txt', 'アリス本作一。');
      write(ownDir, '002.txt', 'アリス本作二。');
      write(ancestorDir, '001.txt', 'アリス祖先一。');
      write(ancestorDir, '002.txt', 'アリス祖先二。');
      final client = _EchoClient(failOn: ['アリス']);

      await expectLater(
        service(client).generateSummary(
          directoryPath: ownDir.path,
          word: 'アリス',
          coveredUpToEpisode: 2,
          referenceSources: [ancestor()],
        ),
        throwsA(
          isA<LlmAnalysisPartialFailure>().having(
            (f) => f.failedFileCount,
            'failedFileCount',
            LlmSummaryService.maxConsecutiveFailures,
          ),
        ),
      );
      expect(
        client.extractionPrompts.join(),
        isNot(contains('祖先二')),
        reason: 'the run gives up after the third consecutive failure',
      );
    });
  });

  test('re-analysis invalidates the ancestor\'s cached facts too', () async {
    write(ownDir, '001.txt', '本作でアリスが旅に出る。');
    const ancestorText = '祖先三話でアリスが登場。';
    write(ancestorDir, '003.txt', ancestorText);
    await FactCacheRepository(ancestorDb).upsert(
      word: 'アリス',
      fileName: '003.txt',
      facts: '- 古い事実',
      contentHash: computeContentHash(ancestorText),
      promptVersion: FactCacheRepository.currentPromptVersion,
      modelId: 'test:fake',
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await LlmSummaryRepository(
      ownDb,
    ).saveSnapshot(word: 'アリス', coveredUpToEpisode: 1, summary: '古い要約');
    final client = _EchoClient();

    await service(client).generateSummary(
      directoryPath: ownDir.path,
      word: 'アリス',
      coveredUpToEpisode: 1,
      referenceSources: [ancestor()],
    );

    expect(client.extractionPrompts.join(), contains('祖先三話'));
    expect(client.summaryPrompts.single, isNot(contains('古い事実')));
  });

  group('snapshot record', () {
    test('records every resolved ancestor in the given order', () async {
      write(ownDir, '001.txt', '本作でアリスが旅に出る。');
      write(ancestorDir, '001.txt', '祖先でアリス。');
      final wikiDir = await Directory.systemTemp.createTemp('ref_wiki_');
      addTearDown(() => wikiDir.delete(recursive: true));
      final wikiDb = await openInMemoryNovelDataDb();
      addTearDown(wikiDb.close);
      File(p.join(wikiDir.path, '001.txt')).writeAsStringSync('無関係。');

      await service(_EchoClient()).generateSummary(
        directoryPath: ownDir.path,
        word: 'アリス',
        coveredUpToEpisode: 1,
        referenceSources: [
          ancestor(),
          ReferenceSourceScope(
            folderName: 'web_wiki',
            title: 'Wiki',
            folderPath: wikiDir.path,
            factCacheRepository: FactCacheRepository(wikiDb),
          ),
        ],
      );

      final snapshot = (await LlmSummaryRepository(ownDb).findAll()).single;
      expect(snapshot.referenceSources, const [
        SnapshotReferenceSource(folderName: 'narou_p1', title: '第1部'),
        SnapshotReferenceSource(folderName: 'web_wiki', title: 'Wiki'),
      ]);
    });

    test('without reference sources the snapshot records none', () async {
      write(ownDir, '001.txt', '本作でアリスが旅に出る。');
      final client = _EchoClient();

      await service(client).generateSummary(
        directoryPath: ownDir.path,
        word: 'アリス',
        coveredUpToEpisode: 1,
      );

      final snapshot = (await LlmSummaryRepository(ownDb).findAll()).single;
      expect(snapshot.referenceSources, isEmpty);
      expect(client.extractionPrompts, hasLength(1));
      expect(client.summaryPrompts.single, isNot(contains('本作の事実を優先')));
    });
  });
}
