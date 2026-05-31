import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockLlmClient extends LlmClient {
  final List<String> responses;
  final List<String> prompts = [];
  final List<String> events = [];
  int _callIndex = 0;
  int releaseCallCount = 0;
  Object? generateError;
  Object? releaseError;

  _MockLlmClient(this.responses);

  @override
  Future<String> generate(String prompt) async {
    events.add('generate');
    prompts.add(prompt);
    if (generateError != null) {
      throw generateError!;
    }
    final response = responses[_callIndex % responses.length];
    _callIndex++;
    return response;
  }

  @override
  Future<void> releaseResources() async {
    events.add('release');
    releaseCallCount++;
    if (releaseError != null) {
      throw releaseError!;
    }
  }

  int get callCount => _callIndex;
}

void main() {
  late Database db;
  late LlmSummaryRepository repository;
  late FactCacheRepository factCache;
  late TextSearchService searchService;
  late Directory tempDir;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE word_summaries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              folder_name TEXT NOT NULL,
              word TEXT NOT NULL,
              covered_up_to_episode INTEGER NOT NULL,
              summary TEXT NOT NULL,
              source_file TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_word_summaries_unique
            ON word_summaries(folder_name, word, covered_up_to_episode)
          ''');
          await db.execute('''
            CREATE TABLE fact_cache (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              folder_name TEXT NOT NULL,
              word TEXT NOT NULL,
              file_name TEXT NOT NULL,
              facts TEXT NOT NULL,
              content_hash TEXT NOT NULL,
              prompt_version INTEGER NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_fact_cache_unique
            ON fact_cache(folder_name, word, file_name)
          ''');
        },
      ),
    );
    repository = LlmSummaryRepository(db);
    factCache = FactCacheRepository(db);
    searchService = TextSearchService();
    tempDir = await Directory.systemTemp.createTemp('llm_service_test_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> createFile(String name, String content) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsString(content);
  }

  group('LlmSummaryService', () {
    test('analyzes "all files" when coveredUpToEpisode equals the max prefix',
        () async {
      await createFile('001_chapter.txt', 'アリスが登場した。');
      await createFile('050_chapter.txt', 'アリスが旅に出た。');
      await createFile('100_chapter.txt', 'アリスが帰還した。');

      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 物語の序盤に登場'}),
        jsonEncode({'facts': '- 旅に出た'}),
        jsonEncode({'facts': '- 帰還した'}),
        jsonEncode({'summary': 'アリスは冒険者。'}),
      ]);

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        factCacheRepository: factCache,
        searchService: searchService,
      );

      final result = await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'test_novel',
        word: 'アリス',
        coveredUpToEpisode: 100,
        sourceFileName: '100_chapter.txt',
      );

      expect(result, 'アリスは冒険者。');
      // 3 files extracted (per-file Stage-1) + 1 final summary.
      expect(mockClient.callCount, 4);

      final cached = await repository.findSnapshotsForWord(
        folderName: 'test_novel',
        word: 'アリス',
      );
      expect(cached, hasLength(1));
      expect(cached.first.coveredUpToEpisode, 100);
      expect(cached.first.sourceFile, '100_chapter.txt');
    });

    test('filters out files whose numeric prefix is greater than the bound',
        () async {
      await createFile('001_chapter.txt', 'アリスが登場した。');
      await createFile('040_chapter.txt', 'アリスが旅に出た。');
      await createFile('100_chapter.txt', 'アリスが帰還した。');

      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 物語の序盤に登場'}),
        jsonEncode({'facts': '- 旅に出た'}),
        jsonEncode({'summary': 'アリスは旅立った少女。'}),
      ]);

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        factCacheRepository: factCache,
        searchService: searchService,
      );

      final result = await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'test_novel',
        word: 'アリス',
        coveredUpToEpisode: 40,
        sourceFileName: '040_chapter.txt',
      );

      expect(result, 'アリスは旅立った少女。');
      // Per-file Stage-1: 001 and 040 each get their own extraction prompt;
      // 100 is filtered out and never extracted.
      final extractionPrompts = mockClient.prompts.take(2).join('\n');
      expect(extractionPrompts, contains('アリスが登場した'));
      expect(extractionPrompts, contains('アリスが旅に出た'));
      expect(extractionPrompts, isNot(contains('アリスが帰還した')));
    });

    test('saves snapshot at the provided coveredUpToEpisode', () async {
      await createFile('001_chapter.txt', 'アリスが登場した。');
      await createFile('060_chapter.txt', 'アリスが旅に出た。');

      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 登場した'}),
        jsonEncode({'facts': '- 旅に出た'}),
        jsonEncode({'summary': 'アリスは冒険者。'}),
      ]);

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        factCacheRepository: factCache,
        searchService: searchService,
      );

      await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'my_novel',
        word: 'アリス',
        coveredUpToEpisode: 60,
        sourceFileName: '060_chapter.txt',
      );

      final snapshots = await repository.findSnapshotsForWord(
        folderName: 'my_novel',
        word: 'アリス',
      );

      expect(snapshots, hasLength(1));
      expect(snapshots.first.coveredUpToEpisode, 60);
      expect(snapshots.first.sourceFile, '060_chapter.txt');
    });

    test('handles empty search results', () async {
      await createFile('001.txt', '関係ないテキスト');

      final mockClient = _MockLlmClient([
        jsonEncode({'summary': '情報が見つかりません。'}),
      ]);

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        factCacheRepository: factCache,
        searchService: searchService,
      );

      final result = await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'test',
        word: 'アリス',
        coveredUpToEpisode: 1,
        sourceFileName: '001.txt',
      );

      expect(result, '情報が見つかりません。');
    });

    test('releases LLM client resources after successful generation',
        () async {
      await createFile('001.txt', 'アリスが登場した。');

      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 登場した'}),
        jsonEncode({'summary': 'アリスは登場人物。'}),
      ]);

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        factCacheRepository: factCache,
        searchService: searchService,
      );

      final result = await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'test',
        word: 'アリス',
        coveredUpToEpisode: 1,
        sourceFileName: '001.txt',
      );

      expect(result, 'アリスは登場人物。');
      expect(mockClient.releaseCallCount, 1);
      expect(mockClient.events.last, 'release');
    });

    test('releases resources when pipeline throws, rethrows original exception',
        () async {
      await createFile('001.txt', 'アリスが登場した。');

      final mockClient = _MockLlmClient(<String>[])
        ..generateError = Exception('pipeline failure');

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        factCacheRepository: factCache,
        searchService: searchService,
      );

      Object? thrown;
      try {
        await service.generateSummary(
          directoryPath: tempDir.path,
          folderName: 'test',
          word: 'アリス',
          coveredUpToEpisode: 1,
          sourceFileName: '001.txt',
        );
      } catch (e) {
        thrown = e;
      }

      expect(thrown, isA<Exception>());
      expect(thrown.toString(), contains('pipeline failure'));
      expect(mockClient.releaseCallCount, 1);
    });

    test('release failure is swallowed when generation succeeded', () async {
      await createFile('001.txt', 'アリスが登場した。');

      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 登場した'}),
        jsonEncode({'summary': '要約OK'}),
      ])
        ..releaseError = Exception('release boom');

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        factCacheRepository: factCache,
        searchService: searchService,
      );

      final result = await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'test',
        word: 'アリス',
        coveredUpToEpisode: 1,
        sourceFileName: '001.txt',
      );

      expect(result, '要約OK');
      expect(mockClient.releaseCallCount, 1);
    });

    test('forwards pipeline progress events to onProgress callback',
        () async {
      await createFile('001.txt', 'アリスが登場した。');

      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 登場した'}),
        jsonEncode({'summary': '進捗パススルー要約'}),
      ]);

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        factCacheRepository: factCache,
        searchService: searchService,
      );

      final events = <AnalysisProgress>[];
      await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'test',
        word: 'アリス',
        coveredUpToEpisode: 1,
        sourceFileName: '001.txt',
        onProgress: events.add,
      );

      expect(
        events.whereType<AnalysisExtractingFacts>().any((e) => e.round == 1),
        isTrue,
      );
      expect(events.whereType<AnalysisGeneratingFinalSummary>().length, 1);
    });

    test('original generation exception propagates when release also throws',
        () async {
      await createFile('001.txt', 'アリスが登場した。');

      final mockClient = _MockLlmClient(<String>[])
        ..generateError = Exception('original generation failure')
        ..releaseError = Exception('secondary release failure');

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        factCacheRepository: factCache,
        searchService: searchService,
      );

      Object? thrown;
      try {
        await service.generateSummary(
          directoryPath: tempDir.path,
          folderName: 'test',
          word: 'アリス',
          coveredUpToEpisode: 1,
          sourceFileName: '001.txt',
        );
      } catch (e) {
        thrown = e;
      }

      expect(thrown.toString(), contains('original generation failure'));
      expect(
          thrown.toString(), isNot(contains('secondary release failure')));
      expect(mockClient.releaseCallCount, 1);
    });

    test('files without numeric prefix are filtered by lexical rank', () async {
      await createFile('intro.txt', 'アリスが登場した。');
      await createFile('part1.txt', 'アリスが旅に出た。');
      await createFile('part2.txt', 'アリスが戻った。');

      final mockClient = _MockLlmClient([
        jsonEncode({'facts': '- 登場'}),
        jsonEncode({'facts': '- 旅'}),
        jsonEncode({'summary': '中盤までの要約。'}),
      ]);

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        factCacheRepository: factCache,
        searchService: searchService,
      );

      // coveredUpToEpisode=2 means include intro.txt (rank 1) and part1.txt
      // (rank 2), but exclude part2.txt (rank 3).
      await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'test',
        word: 'アリス',
        coveredUpToEpisode: 2,
        sourceFileName: 'part1.txt',
      );

      // Per-file Stage-1: intro and part1 each get their own extraction
      // prompt; part2 is filtered out and never extracted.
      final extractionPrompts = mockClient.prompts.take(2).join('\n');
      expect(extractionPrompts, contains('アリスが登場した'));
      expect(extractionPrompts, contains('アリスが旅に出た'));
      expect(extractionPrompts, isNot(contains('アリスが戻った')));
    });
  });
}
