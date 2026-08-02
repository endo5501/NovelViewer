import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_data_db_fixture.dart';

/// Answers from a per-prompt script: the first entry whose key the prompt
/// contains wins, so tests do not have to predict call ordering. A `String`
/// value is returned; any other value is thrown.
class _ScriptedLlmClient extends LlmClient {
  _ScriptedLlmClient(this.byPromptContains, {required this.summary});

  final Map<String, Object> byPromptContains;
  final Object summary;
  int callCount = 0;

  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async {
    callCount++;
    if (schema?.fieldName == 'summary') return _answer(summary);
    for (final entry in byPromptContains.entries) {
      if (prompt.contains(entry.key)) return _answer(entry.value);
    }
    return _answer(jsonEncode({'facts': '- 既定の事実'}));
  }

  String _answer(Object outcome) {
    if (outcome is String) return outcome;
    throw outcome;
  }
}

void main() {
  late Database db;
  late LlmSummaryRepository repository;
  late FactCacheRepository factCache;
  late TextSearchService searchService;
  late Directory tempDir;

  setUp(() async {
    sqfliteFfiInit();
    db = await openInMemoryNovelDataDb();
    repository = LlmSummaryRepository(db);
    factCache = FactCacheRepository(db);
    searchService = TextSearchService();
    tempDir = await Directory.systemTemp.createTemp('llm_failure_test_');
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

  LlmSummaryService makeService(LlmClient client) => LlmSummaryService(
        llmClient: client,
        repository: repository,
        factCacheRepository: factCache,
        searchService: searchService,
      );

  group('fact-cache write gate', () {
    test('a raw-text fallback result is not cached', () async {
      await createFile('001_ch.txt', 'アリスはエピソード1で登場した。');
      await createFile('002_ch.txt', 'アリスはエピソード2で旅立った。');

      final client = _ScriptedLlmClient(
        {
          // Not JSON: the parser falls back to raw text.
          'エピソード1': '- 素のテキストで返ってきた事実',
          'エピソード2': jsonEncode({'facts': '- 旅立った'}),
        },
        summary: jsonEncode({'summary': 'アリスは冒険者。'}),
      );

      await makeService(client).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 2,
      );

      expect(
        await factCache.find(word: 'アリス', fileName: '001_ch.txt'),
        isNull,
      );
      expect(
        (await factCache.find(word: 'アリス', fileName: '002_ch.txt'))?.facts,
        '- 旅立った',
      );
    });

    test('an empty facts result is not cached', () async {
      await createFile('001_ch.txt', 'アリスはエピソード1で登場した。');
      await createFile('002_ch.txt', 'アリスはエピソード2で旅立った。');

      final client = _ScriptedLlmClient(
        {
          'エピソード1': jsonEncode({'facts': '   '}),
          'エピソード2': jsonEncode({'facts': '- 旅立った'}),
        },
        summary: jsonEncode({'summary': 'アリスは冒険者。'}),
      );

      await makeService(client).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 2,
      );

      expect(
        await factCache.find(word: 'アリス', fileName: '001_ch.txt'),
        isNull,
      );
    });

    test('a structured, non-empty result is cached', () async {
      await createFile('001_ch.txt', 'アリスはエピソード1で登場した。');

      final client = _ScriptedLlmClient(
        {'エピソード1': jsonEncode({'facts': '- 登場した'})},
        summary: jsonEncode({'summary': 'アリスは冒険者。'}),
      );

      await makeService(client).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 1,
      );

      final row = await factCache.find(word: 'アリス', fileName: '001_ch.txt');
      expect(row?.facts, '- 登場した');
      expect(row?.promptVersion, FactCacheRepository.currentPromptVersion);
    });

    test('a withheld file is re-extracted on the next run', () async {
      await createFile('001_ch.txt', 'アリスはエピソード1で登場した。');
      await createFile('002_ch.txt', 'アリスはエピソード2で旅立った。');

      final first = _ScriptedLlmClient(
        {
          'エピソード1': '- 素のテキストで返ってきた事実',
          'エピソード2': jsonEncode({'facts': '- 旅立った'}),
        },
        summary: jsonEncode({'summary': 'アリスは冒険者。'}),
      );
      await makeService(first).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 2,
      );

      final second = _ScriptedLlmClient(
        {
          'エピソード1': jsonEncode({'facts': '- 登場した'}),
          'エピソード2': jsonEncode({'facts': '- 旅立った'}),
        },
        summary: jsonEncode({'summary': 'アリスは冒険者。'}),
      );
      await makeService(second).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 3,
      );

      // File 2 came from the cache; only file 1 was extracted again, plus the
      // final summary.
      expect(second.callCount, 2);
      expect(
        (await factCache.find(word: 'アリス', fileName: '001_ch.txt'))?.facts,
        '- 登場した',
      );
    });
  });

  group('file-level failure isolation', () {
    Future<void> createEpisodes(int count) async {
      for (var i = 1; i <= count; i++) {
        await createFile('00${i}_ch.txt', 'アリスはエピソード$iで行動した。');
      }
    }

    test('extraction continues past a failed file and caches the successes',
        () async {
      await createEpisodes(5);

      // File 3 fails both its attempt and its retry.
      final client = _ScriptedLlmClient(
        {'エピソード3': const SocketException('connection reset')},
        summary: jsonEncode({'summary': 'アリスは冒険者。'}),
      );

      await expectLater(
        () => makeService(client).generateSummary(
          directoryPath: tempDir.path,
          word: 'アリス',
          coveredUpToEpisode: 5,
        ),
        throwsA(isA<LlmAnalysisPartialFailure>()),
      );

      for (final name in ['001_ch.txt', '002_ch.txt', '004_ch.txt', '005_ch.txt']) {
        expect(
          await factCache.find(word: 'アリス', fileName: name),
          isNotNull,
          reason: '$name should have been extracted and cached',
        );
      }
      expect(
        await factCache.find(word: 'アリス', fileName: '003_ch.txt'),
        isNull,
      );
    });

    test('a failed file prevents summary generation and persistence', () async {
      await createEpisodes(5);

      final client = _ScriptedLlmClient(
        {'エピソード3': const SocketException('connection reset')},
        summary: jsonEncode({'summary': 'アリスは冒険者。'}),
      );

      await expectLater(
        () => makeService(client).generateSummary(
          directoryPath: tempDir.path,
          word: 'アリス',
          coveredUpToEpisode: 5,
        ),
        throwsA(isA<LlmAnalysisPartialFailure>()
            .having((e) => e.failedFileCount, 'failedFileCount', 1)),
      );

      expect(await repository.findSnapshotsForWord(word: 'アリス'), isEmpty);
      // 4 successes + 2 attempts for the failing file, and no final summary.
      expect(client.callCount, 6);
    });

    test('a re-run after a partial failure only re-extracts the failed file',
        () async {
      await createEpisodes(5);

      final first = _ScriptedLlmClient(
        {'エピソード3': const SocketException('connection reset')},
        summary: jsonEncode({'summary': 'アリスは冒険者。'}),
      );
      await expectLater(
        () => makeService(first).generateSummary(
          directoryPath: tempDir.path,
          word: 'アリス',
          coveredUpToEpisode: 5,
        ),
        throwsA(isA<LlmAnalysisPartialFailure>()),
      );

      final second = _ScriptedLlmClient(
        const {},
        summary: jsonEncode({'summary': 'アリスは冒険者。'}),
      );
      final summary = await makeService(second).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 5,
      );

      expect(summary, 'アリスは冒険者。');
      // Only file 3 is re-extracted, then the final summary.
      expect(second.callCount, 2);
    });

    test('a fully successful run persists as before', () async {
      await createEpisodes(3);

      final client = _ScriptedLlmClient(
        const {},
        summary: jsonEncode({'summary': 'アリスは冒険者。'}),
      );

      final summary = await makeService(client).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 3,
      );

      expect(summary, 'アリスは冒険者。');
      expect(await repository.findSnapshotsForWord(word: 'アリス'), hasLength(1));
    });
  });

  group('re-analysis invalidation scope', () {
    Future<void> createEpisodes(int count) async {
      for (var i = 1; i <= count; i++) {
        await createFile('00${i}_ch.txt', 'アリスはエピソード$iで行動した。');
      }
    }

    test('re-analysis still forces fresh extraction of pre-snapshot rows',
        () async {
      await createEpisodes(3);

      final first = _ScriptedLlmClient(
        const {},
        summary: jsonEncode({'summary': '初回要約。'}),
      );
      await makeService(first).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 3,
      );

      final second = _ScriptedLlmClient(
        const {},
        summary: jsonEncode({'summary': '再解析要約。'}),
      );
      final summary = await makeService(second).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 3,
      );

      expect(summary, '再解析要約。');
      // Every file re-extracted (3) plus the final summary.
      expect(second.callCount, 4);
    });

    test('a failed re-analysis attempt keeps its extractions for the next try',
        () async {
      await createEpisodes(5);

      // A successful first analysis creates the snapshot that makes later runs
      // count as re-analyses.
      await makeService(_ScriptedLlmClient(
        const {},
        summary: jsonEncode({'summary': '初回要約。'}),
      )).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 5,
      );

      // Re-analysis: file 3 fails, so nothing is saved — but files 1,2,4,5 were
      // re-extracted and must survive the next attempt's invalidation.
      final failing = _ScriptedLlmClient(
        {'エピソード3': const SocketException('connection reset')},
        summary: jsonEncode({'summary': '再解析要約。'}),
      );
      await expectLater(
        () => makeService(failing).generateSummary(
          directoryPath: tempDir.path,
          word: 'アリス',
          coveredUpToEpisode: 5,
        ),
        throwsA(isA<LlmAnalysisPartialFailure>()),
      );

      final retry = _ScriptedLlmClient(
        const {},
        summary: jsonEncode({'summary': '再解析要約。'}),
      );
      final summary = await makeService(retry).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 5,
      );

      expect(summary, '再解析要約。');
      // Only file 3 is extracted again, then the final summary. Without the
      // scoped invalidation this would be 6 (all five files re-extracted).
      expect(retry.callCount, 2);
    });

    test('a row refreshed by a later wider analysis is still re-extracted',
        () async {
      await createEpisodes(3);

      // Snapshot at ep3.
      await makeService(_ScriptedLlmClient(
        const {},
        summary: jsonEncode({'summary': 'ep3要約。'}),
      )).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 3,
      );

      // 002 changes, then a wider analysis at ep6 sees it as a hash miss and
      // rewrites its cache row with a timestamp later than the ep3 snapshot.
      await createFile('002_ch.txt', 'アリスはエピソード2で別の行動をした。');
      for (var i = 4; i <= 6; i++) {
        await createFile('00${i}_ch.txt', 'アリスはエピソード$iで行動した。');
      }
      await makeService(_ScriptedLlmClient(
        const {},
        summary: jsonEncode({'summary': 'ep6要約。'}),
      )).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 6,
      );

      // Re-analyzing ep3 means "redo from scratch". 002's row is newer than the
      // ep3 snapshot but was NOT produced by a failed attempt, so it must still
      // be re-extracted — otherwise the file the user is trying to fix is the
      // one served from cache.
      final reanalysis = _ScriptedLlmClient(
        const {},
        summary: jsonEncode({'summary': 'ep3再解析。'}),
      );
      await makeService(reanalysis).generateSummary(
        directoryPath: tempDir.path,
        word: 'アリス',
        coveredUpToEpisode: 3,
      );

      // Three files re-extracted plus the final summary.
      expect(reanalysis.callCount, 4);
    });
  });

  group('empty aggregated facts', () {
    test('empty facts never reach the final summary call', () async {
      await createFile('001_ch.txt', 'アリスはエピソード1で登場した。');

      final client = _ScriptedLlmClient(
        {'エピソード1': jsonEncode({'facts': '   '})},
        summary: jsonEncode({'summary': '幻覚された要約。'}),
      );

      await expectLater(
        () => makeService(client).generateSummary(
          directoryPath: tempDir.path,
          word: 'アリス',
          coveredUpToEpisode: 1,
        ),
        throwsA(isA<Exception>()),
      );

      // The extraction happened; the final summary call did not.
      expect(client.callCount, 1);
      expect(await repository.findSnapshotsForWord(word: 'アリス'), isEmpty);
    });
  });
}
