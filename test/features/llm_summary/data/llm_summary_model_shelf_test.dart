import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:novel_viewer/shared/utils/content_hash.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_data_db_fixture.dart';

/// A client that names whichever model the test wants and signs the facts it
/// produces, so a run's evidence can be traced back to who wrote it.
class _NamedClient extends LlmClient {
  _NamedClient(this.modelId);

  @override
  final String modelId;

  final List<String> extractionPrompts = [];

  @override
  Future<String> generate(String prompt, {LlmResponseSchema? schema}) async {
    if (schema?.fieldName == 'summary') {
      return jsonEncode({'summary': '$modelId のまとめ'});
    }
    extractionPrompts.add(prompt);
    return jsonEncode({'facts': '- $modelId が書いた事実'});
  }
}

void main() {
  const server = 'ollama:qwen3:30b';
  const device = 'apple:on-device';

  late Database db;
  late LlmSummaryRepository repository;
  late FactCacheRepository factCache;
  late Directory tempDir;

  setUp(() async {
    sqfliteFfiInit();
    db = await openInMemoryNovelDataDb();
    repository = LlmSummaryRepository(db);
    factCache = FactCacheRepository(db);
    tempDir = await Directory.systemTemp.createTemp('llm_model_shelf_test_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> writeEpisode(String name) =>
      File('${tempDir.path}/$name').writeAsString('アリスは騎士団の副長である。');

  Future<void> seedCache(String fileName, String modelId, String facts) async {
    final content = await File('${tempDir.path}/$fileName').readAsString();
    await factCache.upsert(
      word: 'アリス',
      fileName: fileName,
      facts: facts,
      contentHash: computeContentHash(content),
      promptVersion: FactCacheRepository.currentPromptVersion,
      modelId: modelId,
    );
  }

  Future<_NamedClient> analyzeWith(String modelId, {required int upTo}) async {
    final client = _NamedClient(modelId);
    await LlmSummaryService(
      llmClient: client,
      repository: repository,
      factCacheRepository: factCache,
      searchService: TextSearchService(),
    ).generateSummary(
      directoryPath: tempDir.path,
      word: 'アリス',
      coveredUpToEpisode: upTo,
    );
    return client;
  }

  group('an analysis reads only its own model shelf', () {
    test('a valid row from another model does not spare the call', () async {
      await writeEpisode('001_ch.txt');
      await seedCache('001_ch.txt', server, '- サーバが書いた事実');

      final client = await analyzeWith(device, upTo: 1);

      expect(
        client.extractionPrompts,
        hasLength(1),
        reason: 'the on-device run must extract the file itself',
      );
    });

    test('the other model row survives the run untouched', () async {
      await writeEpisode('001_ch.txt');
      await seedCache('001_ch.txt', server, '- サーバが書いた事実');

      await analyzeWith(device, upTo: 1);

      final kept = await factCache.find(
        word: 'アリス',
        fileName: '001_ch.txt',
        modelId: server,
      );
      expect(kept!.facts, '- サーバが書いた事実');
    });

    test('the run writes its facts to its own shelf', () async {
      await writeEpisode('001_ch.txt');
      await seedCache('001_ch.txt', server, '- サーバが書いた事実');

      await analyzeWith(device, upTo: 1);

      final written = await factCache.find(
        word: 'アリス',
        fileName: '001_ch.txt',
        modelId: device,
      );
      expect(written!.facts, '- $device が書いた事実');
    });

    test('a valid row from the same model does spare the call', () async {
      await writeEpisode('001_ch.txt');
      await seedCache('001_ch.txt', device, '- 端末が前に書いた事実');

      final client = await analyzeWith(device, upTo: 1);

      expect(client.extractionPrompts, isEmpty);
    });
  });

  group('a run assembles facts from one model only', () {
    test('files cached under another model are re-extracted', () async {
      // Three files: one already on this model's shelf, one on the other
      // model's, one on neither. This is the shape of "analysed on the device
      // up to here, then switched to a server and read on".
      for (final name in ['001_ch.txt', '002_ch.txt', '003_ch.txt']) {
        await writeEpisode(name);
      }
      await seedCache('001_ch.txt', server, '- サーバが前に書いた事実');
      await seedCache('002_ch.txt', device, '- 端末が前に書いた事実');

      final client = await analyzeWith(server, upTo: 3);

      // 002 and 003 are misses for the server; 001 is its own hit.
      expect(client.extractionPrompts, hasLength(2));

      final rows = await factCache.findForWord(word: 'アリス');
      final onServerShelf = rows.where((r) => r.modelId == server);
      expect(onServerShelf.map((r) => r.fileName).toSet(), {
        '001_ch.txt',
        '002_ch.txt',
        '003_ch.txt',
      });
      // Every fact the run could have used carries the server's name, except
      // the one it had cached itself, which is the same shelf.
      expect(
        onServerShelf.every(
          (r) => r.facts.contains(server) || r.facts == '- サーバが前に書いた事実',
        ),
        isTrue,
      );
      // The device's own row is still there, unchanged.
      expect(
        rows.singleWhere((r) => r.modelId == device).facts,
        '- 端末が前に書いた事実',
      );
    });
  });

  group('re-analysis invalidates one shelf', () {
    test('the other model rows keep their facts', () async {
      await writeEpisode('001_ch.txt');
      await analyzeWith(device, upTo: 1);
      await analyzeWith(server, upTo: 1);

      // Both shelves now hold 001. Re-analyse at the same bound on the server.
      final client = await analyzeWith(server, upTo: 1);

      expect(
        client.extractionPrompts,
        hasLength(1),
        reason: 're-analysis must not serve its own cached facts',
      );
      final deviceRow = await factCache.find(
        word: 'アリス',
        fileName: '001_ch.txt',
        modelId: device,
      );
      expect(deviceRow!.facts, '- $device が書いた事実');
      expect(deviceRow.contentHash, isNot(FactCacheRepository.sentinelHash));
    });

    test('a switch to an unused model extracts everything anyway', () async {
      await writeEpisode('001_ch.txt');
      await writeEpisode('002_ch.txt');
      await analyzeWith(server, upTo: 2);

      // The device has never analysed this word, so its shelf is empty and the
      // invalidation finds nothing to revoke.
      final client = await analyzeWith(device, upTo: 2);

      expect(client.extractionPrompts, hasLength(2));
    });
  });
}
