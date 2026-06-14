import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';
import 'package:novel_viewer/shared/utils/content_hash.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

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
  late Database db;
  late LlmSummaryRepository repository;
  late FactCacheRepository factCache;
  late TextSearchService searchService;
  late Directory tempDir;

  setUp(() async {
    sqfliteFfiInit();
    db = await openInMemoryNovelMetadataDb();
    repository = LlmSummaryRepository(db);
    factCache = FactCacheRepository(db);
    searchService = TextSearchService();
    tempDir = await Directory.systemTemp.createTemp('llm_cache_service_test_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> createFile(String name, String content) async {
    await File('${tempDir.path}/$name').writeAsString(content);
  }

  Future<void> seedValidCache(String fileName, String facts) async {
    final content = await File('${tempDir.path}/$fileName').readAsString();
    await factCache.upsert(
      folderName: 'novelA',
      word: 'アリス',
      fileName: fileName,
      facts: facts,
      contentHash: computeContentHash(content),
      promptVersion: FactCacheRepository.currentPromptVersion,
    );
  }

  LlmSummaryService makeService(_MockLlmClient client) => LlmSummaryService(
        llmClient: client,
        repository: repository,
        factCacheRepository: factCache,
        searchService: searchService,
      );

  group('LlmSummaryService fact-cache orchestration', () {
    test('reuses cached facts for prior files and extracts only the misses',
        () async {
      for (var i = 1; i <= 7; i++) {
        await createFile(
            '00${i}_ch.txt', 'アリスはエピソード$iで行動した。');
      }
      // Files 1-5 already cached (valid). Files 6,7 are misses.
      for (var i = 1; i <= 5; i++) {
        await seedValidCache('00${i}_ch.txt', '- cached事実$i');
      }

      final mock = _MockLlmClient([
        jsonEncode({'facts': '- 事実6'}),
        jsonEncode({'facts': '- 事実7'}),
        jsonEncode({'summary': '組み立て要約。'}),
      ]);

      final result = await makeService(mock).generateSummary(
        directoryPath: tempDir.path,
        folderName: 'novelA',
        word: 'アリス',
        coveredUpToEpisode: 7,
        sourceFileName: '007_ch.txt',
      );

      expect(result, '組み立て要約。');
      // 2 extractions (files 6,7) + 1 final summary == 3 calls.
      expect(mock.callCount, 3);

      // Extraction prompts only for the misses.
      final extractionPrompts = mock.prompts.take(2).join('\n');
      expect(extractionPrompts, contains('エピソード6'));
      expect(extractionPrompts, contains('エピソード7'));
      expect(extractionPrompts, isNot(contains('エピソード1')));

      // The final-summary prompt carries cached facts 1-5 plus fresh 6,7.
      final finalPrompt = mock.prompts.last;
      expect(finalPrompt, contains('cached事実1'));
      expect(finalPrompt, contains('cached事実5'));
      expect(finalPrompt, contains('事実6'));
    });

    test('cold cache extracts every in-scope file (full scan)', () async {
      await createFile('001_ch.txt', 'アリスが登場した。');
      await createFile('002_ch.txt', 'アリスが旅に出た。');

      final mock = _MockLlmClient([
        jsonEncode({'facts': '- 登場'}),
        jsonEncode({'facts': '- 旅'}),
        jsonEncode({'summary': 'アリスは冒険者。'}),
      ]);

      final result = await makeService(mock).generateSummary(
        directoryPath: tempDir.path,
        folderName: 'novelA',
        word: 'アリス',
        coveredUpToEpisode: 2,
        sourceFileName: '002_ch.txt',
      );

      expect(result, 'アリスは冒険者。');
      expect(mock.callCount, 3, reason: '2 files extracted + 1 summary');
    });

    test('changed file content (hash mismatch) re-extracts only that file',
        () async {
      await createFile('001_ch.txt', 'アリスが登場した。');
      await createFile('002_ch.txt', 'アリスが旅に出た。');

      // file1 cached with its real hash (valid); file2 cached with a stale
      // hash (invalid → must re-extract).
      await seedValidCache('001_ch.txt', '- cached登場');
      await factCache.upsert(
        folderName: 'novelA',
        word: 'アリス',
        fileName: '002_ch.txt',
        facts: '- stale旅',
        contentHash: 'STALE',
        promptVersion: FactCacheRepository.currentPromptVersion,
      );

      final mock = _MockLlmClient([
        jsonEncode({'facts': '- fresh旅'}),
        jsonEncode({'summary': '更新要約。'}),
      ]);

      await makeService(mock).generateSummary(
        directoryPath: tempDir.path,
        folderName: 'novelA',
        word: 'アリス',
        coveredUpToEpisode: 2,
        sourceFileName: '002_ch.txt',
      );

      expect(mock.callCount, 2, reason: 'only file2 re-extracted + summary');
      final extractionPrompt = mock.prompts.first;
      expect(extractionPrompt, contains('アリスが旅に出た'));
      expect(extractionPrompt, isNot(contains('アリスが登場した')));
    });

    test('prompt-version mismatch re-extracts the file', () async {
      await createFile('001_ch.txt', 'アリスが登場した。');

      final content =
          await File('${tempDir.path}/001_ch.txt').readAsString();
      await factCache.upsert(
        folderName: 'novelA',
        word: 'アリス',
        fileName: '001_ch.txt',
        facts: '- 旧プロンプト事実',
        contentHash: computeContentHash(content),
        promptVersion: FactCacheRepository.currentPromptVersion + 1,
      );

      final mock = _MockLlmClient([
        jsonEncode({'facts': '- 新プロンプト事実'}),
        jsonEncode({'summary': '再抽出要約。'}),
      ]);

      await makeService(mock).generateSummary(
        directoryPath: tempDir.path,
        folderName: 'novelA',
        word: 'アリス',
        coveredUpToEpisode: 1,
        sourceFileName: '001_ch.txt',
      );

      expect(mock.callCount, 2, reason: 'stale prompt version → re-extract');
    });

    test(
        're-analysis at an existing covered invalidates the word cache and '
        're-extracts', () async {
      await createFile('001_ch.txt', 'アリスが登場した。');
      await createFile('002_ch.txt', 'アリスが旅に出た。');

      // First (cold) analysis at covered=2 caches both files + saves snapshot.
      final mock1 = _MockLlmClient([
        jsonEncode({'facts': '- f1'}),
        jsonEncode({'facts': '- f2'}),
        jsonEncode({'summary': '初回要約。'}),
      ]);
      await makeService(mock1).generateSummary(
        directoryPath: tempDir.path,
        folderName: 'novelA',
        word: 'アリス',
        coveredUpToEpisode: 2,
        sourceFileName: '002_ch.txt',
      );
      expect(mock1.callCount, 3);

      // Re-analysis at the SAME covered=2: a snapshot already exists, so the
      // word cache is invalidated and both files are re-extracted (no reuse).
      final mock2 = _MockLlmClient([
        jsonEncode({'facts': '- f1b'}),
        jsonEncode({'facts': '- f2b'}),
        jsonEncode({'summary': '再解析要約。'}),
      ]);
      final result = await makeService(mock2).generateSummary(
        directoryPath: tempDir.path,
        folderName: 'novelA',
        word: 'アリス',
        coveredUpToEpisode: 2,
        sourceFileName: '002_ch.txt',
      );

      expect(result, '再解析要約。');
      expect(mock2.callCount, 3,
          reason: 're-analysis re-extracts both files instead of reusing cache');

      final snaps = await repository.findSnapshotsForWord(
          folderName: 'novelA', word: 'アリス');
      expect(snaps, hasLength(1));
      expect(snaps.first.summary, '再解析要約。',
          reason: 'snapshot overwritten with the fresh summary');
    });

    test('analysis at a NEW covered reuses cache (not treated as re-analysis)',
        () async {
      await createFile('001_ch.txt', 'アリスが登場した。');
      await createFile('002_ch.txt', 'アリスが旅に出た。');

      // Analyze@1 → only file1 in scope; caches file1, snapshot@1.
      final mock1 = _MockLlmClient([
        jsonEncode({'facts': '- f1'}),
        jsonEncode({'summary': 'cov1。'}),
      ]);
      await makeService(mock1).generateSummary(
        directoryPath: tempDir.path,
        folderName: 'novelA',
        word: 'アリス',
        coveredUpToEpisode: 1,
        sourceFileName: '001_ch.txt',
      );

      // Analyze@2 (a new covered, no snapshot@2) → reuse file1, extract file2.
      final mock2 = _MockLlmClient([
        jsonEncode({'facts': '- f2'}),
        jsonEncode({'summary': 'cov2。'}),
      ]);
      await makeService(mock2).generateSummary(
        directoryPath: tempDir.path,
        folderName: 'novelA',
        word: 'アリス',
        coveredUpToEpisode: 2,
        sourceFileName: '002_ch.txt',
      );

      expect(mock2.callCount, 2,
          reason: 'file1 reused from cache; only file2 extracted + summary');
    });

    test('round-1 progress counters reflect only the extracted (miss) files',
        () async {
      for (var i = 1; i <= 3; i++) {
        await createFile('00${i}_ch.txt', 'アリスはエピソード$iにいた。');
      }
      // file1 cached (valid hit); files 2,3 are misses.
      await seedValidCache('001_ch.txt', '- cached1');

      final mock = _MockLlmClient([
        jsonEncode({'facts': '- 事実2'}),
        jsonEncode({'facts': '- 事実3'}),
        jsonEncode({'summary': '要約。'}),
      ]);

      final events = <AnalysisProgress>[];
      await makeService(mock).generateSummary(
        directoryPath: tempDir.path,
        folderName: 'novelA',
        word: 'アリス',
        coveredUpToEpisode: 3,
        sourceFileName: '003_ch.txt',
        onProgress: events.add,
      );

      final round1 = events
          .whereType<AnalysisExtractingFacts>()
          .where((e) => e.round == 1)
          .toList();
      expect(round1, hasLength(2), reason: 'only the 2 misses are extracted');
      expect(round1.every((e) => e.total == 2), isTrue,
          reason: 'total counts misses, not the cache hit');
      expect(round1.map((e) => e.current), [1, 2]);
    });

    test('extracted files are written back to the cache with current hash',
        () async {
      await createFile('001_ch.txt', 'アリスが登場した。');

      final mock = _MockLlmClient([
        jsonEncode({'facts': '- 新規事実'}),
        jsonEncode({'summary': '書き戻し要約。'}),
      ]);

      await makeService(mock).generateSummary(
        directoryPath: tempDir.path,
        folderName: 'novelA',
        word: 'アリス',
        coveredUpToEpisode: 1,
        sourceFileName: '001_ch.txt',
      );

      final content =
          await File('${tempDir.path}/001_ch.txt').readAsString();
      final entry = await factCache.find(
        folderName: 'novelA',
        word: 'アリス',
        fileName: '001_ch.txt',
      );
      expect(entry, isNotNull);
      expect(entry!.facts, '- 新規事実');
      expect(entry.contentHash, computeContentHash(content));
      expect(entry.promptVersion, FactCacheRepository.currentPromptVersion);
    });
  });
}
