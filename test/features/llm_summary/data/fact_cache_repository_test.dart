import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_data_db_fixture.dart';

void main() {
  late Database db;
  late FactCacheRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    db = await openInMemoryNovelDataDb();
    repository = FactCacheRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // The pre-existing behaviour is unchanged when only one model is in play,
  // so these groups pin it against a single shelf.
  const onlyModel = 'ollama:qwen3:30b';

  group('FactCacheRepository', () {
    group('upsert / find', () {
      test('inserts then reads back a row by (word, file)', () async {
        await repository.upsert(
          word: 'アリス',
          fileName: '005_ch.txt',
          facts: '- 王国の王女',
          contentHash: 'hash5',
          promptVersion: 1,
          modelId: onlyModel,
        );

        final entry = await repository.find(
          word: 'アリス',
          fileName: '005_ch.txt',
          modelId: onlyModel,
        );

        expect(entry, isNotNull);
        expect(entry!.facts, '- 王国の王女');
        expect(entry.contentHash, 'hash5');
        expect(entry.promptVersion, 1);
      });

      test('find returns null for a missing row', () async {
        final entry = await repository.find(
          word: 'アリス',
          fileName: 'missing.txt',
          modelId: onlyModel,
        );
        expect(entry, isNull);
      });

      test('upsert replaces in place (no duplicate row)', () async {
        await repository.upsert(
          word: 'アリス',
          fileName: '005_ch.txt',
          facts: '- 古い事実',
          contentHash: 'oldhash',
          promptVersion: 1,
          modelId: onlyModel,
        );
        await repository.upsert(
          word: 'アリス',
          fileName: '005_ch.txt',
          facts: '- 新しい事実',
          contentHash: 'newhash',
          promptVersion: 2,
          modelId: onlyModel,
        );

        final rows = await repository.findForWord(word: 'アリス');
        expect(rows, hasLength(1), reason: 'colliding key SHALL upsert');
        expect(rows.first.facts, '- 新しい事実');
        expect(rows.first.contentHash, 'newhash');
        expect(rows.first.promptVersion, 2);
      });

      test('findForWord returns only the requested word', () async {
        await repository.upsert(
          word: 'アリス',
          fileName: '001.txt',
          facts: 'a',
          contentHash: 'h1',
          promptVersion: 1,
          modelId: onlyModel,
        );
        await repository.upsert(
          word: 'アリス',
          fileName: '002.txt',
          facts: 'b',
          contentHash: 'h2',
          promptVersion: 1,
          modelId: onlyModel,
        );
        await repository.upsert(
          word: 'ボブ',
          fileName: '001.txt',
          facts: 'c',
          contentHash: 'h3',
          promptVersion: 1,
          modelId: onlyModel,
        );

        final rows = await repository.findForWord(word: 'アリス');
        expect(rows, hasLength(2));
        expect(rows.map((r) => r.fileName).toSet(), {'001.txt', '002.txt'});
      });
    });

    group('invalidateWord', () {
      test(
        'sets content_hash to the empty-string sentinel for the word',
        () async {
          await repository.upsert(
            word: 'アリス',
            fileName: '001.txt',
            facts: 'a',
            contentHash: 'h1',
            promptVersion: 1,
            modelId: onlyModel,
          );
          await repository.upsert(
            word: 'アリス',
            fileName: '002.txt',
            facts: 'b',
            contentHash: 'h2',
            promptVersion: 1,
            modelId: onlyModel,
          );
          await repository.upsert(
            word: 'ボブ',
            fileName: '001.txt',
            facts: 'c',
            contentHash: 'h3',
            promptVersion: 1,
            modelId: onlyModel,
          );

          await repository.invalidateWord(word: 'アリス', modelId: onlyModel);

          final alice = await repository.findForWord(word: 'アリス');
          expect(
            alice.every(
              (r) => r.contentHash == FactCacheRepository.sentinelHash,
            ),
            isTrue,
          );
          expect(FactCacheRepository.sentinelHash, '');

          // Other words must be untouched.
          final bob = await repository.findForWord(word: 'ボブ');
          expect(bob.single.contentHash, 'h3');
        },
      );

      Future<void> seed(String fileName, String updatedAt) async {
        await repository.upsert(
          word: 'アリス',
          fileName: fileName,
          facts: 'facts-$fileName',
          contentHash: 'hash-$fileName',
          promptVersion: 1,
          modelId: onlyModel,
        );
        await db.update(
          'fact_cache',
          {'updated_at': updatedAt},
          where: 'word = ? AND file_name = ?',
          whereArgs: ['アリス', fileName],
        );
      }

      Future<String?> hashOf(String fileName) async => (await repository.find(
        word: 'アリス',
        fileName: fileName,
        modelId: onlyModel,
      ))?.contentHash;

      test('rows newer than the reference timestamp are preserved', () async {
        await seed('old.txt', '2026-08-01T00:00:00.000Z');
        await seed('new.txt', '2026-08-03T00:00:00.000Z');

        await repository.invalidateWord(
          word: 'アリス',
          modelId: onlyModel,
          notNewerThan: DateTime.utc(2026, 8, 2),
        );

        expect(await hashOf('old.txt'), FactCacheRepository.sentinelHash);
        expect(await hashOf('new.txt'), 'hash-new.txt');
      });

      test('a row at exactly the reference timestamp is invalidated', () async {
        await seed('exact.txt', '2026-08-02T00:00:00.000Z');

        await repository.invalidateWord(
          word: 'アリス',
          modelId: onlyModel,
          notNewerThan: DateTime.utc(2026, 8, 2),
        );

        expect(await hashOf('exact.txt'), FactCacheRepository.sentinelHash);
      });

      test('facts of a preserved row are left intact', () async {
        await seed('new.txt', '2026-08-03T00:00:00.000Z');

        await repository.invalidateWord(
          word: 'アリス',
          modelId: onlyModel,
          notNewerThan: DateTime.utc(2026, 8, 2),
        );

        final row = await repository.find(
          word: 'アリス',
          fileName: 'new.txt',
          modelId: onlyModel,
        );
        expect(row!.facts, 'facts-new.txt');
      });

      test('omitting the reference timestamp invalidates every row', () async {
        await seed('old.txt', '2026-08-01T00:00:00.000Z');
        await seed('new.txt', '2026-08-03T00:00:00.000Z');

        await repository.invalidateWord(word: 'アリス', modelId: onlyModel);

        expect(await hashOf('old.txt'), FactCacheRepository.sentinelHash);
        expect(await hashOf('new.txt'), FactCacheRepository.sentinelHash);
      });
    });

    group('cascade cleanup', () {
      test('deleteAllForWord removes only that word rows', () async {
        await repository.upsert(
          word: 'アリス',
          fileName: '001.txt',
          facts: 'a',
          contentHash: 'h1',
          promptVersion: 1,
          modelId: onlyModel,
        );
        await repository.upsert(
          word: 'ボブ',
          fileName: '001.txt',
          facts: 'b',
          contentHash: 'h2',
          promptVersion: 1,
          modelId: onlyModel,
        );

        await repository.deleteAllForWord(word: 'アリス');

        expect(await repository.findForWord(word: 'アリス'), isEmpty);
        expect(await repository.findForWord(word: 'ボブ'), hasLength(1));
      });
    });
  });

  group('rows are kept apart by the model that wrote them', () {
    const alice = 'アリス';
    const file = '005_ch.txt';
    const server = 'ollama:qwen3:30b';
    const device = 'apple:on-device';

    Future<void> write(String modelId, String facts) => repository.upsert(
      word: alice,
      fileName: file,
      facts: facts,
      contentHash: 'hash5',
      promptVersion: 1,
      modelId: modelId,
    );

    test('the same file under two models is two rows', () async {
      await write(server, '- サーバが書いた事実');
      await write(device, '- 端末が書いた事実');

      expect(await db.query('fact_cache'), hasLength(2));
    });

    test('find returns the row for the model it was asked about', () async {
      await write(server, '- サーバが書いた事実');
      await write(device, '- 端末が書いた事実');

      final fromServer = await repository.find(
        word: alice,
        fileName: file,
        modelId: server,
      );
      final fromDevice = await repository.find(
        word: alice,
        fileName: file,
        modelId: device,
      );

      expect(fromServer!.facts, '- サーバが書いた事実');
      expect(fromServer.modelId, server);
      expect(fromDevice!.facts, '- 端末が書いた事実');
      expect(fromDevice.modelId, device);
    });

    test('find misses when only another model has the file', () async {
      await write(server, '- サーバが書いた事実');

      expect(
        await repository.find(word: alice, fileName: file, modelId: device),
        isNull,
      );
    });

    test('upsert replaces only within its own model', () async {
      await write(server, '- 古い事実');
      await write(device, '- 端末が書いた事実');
      await write(server, '- 新しい事実');

      expect(await db.query('fact_cache'), hasLength(2));
      final fromServer = await repository.find(
        word: alice,
        fileName: file,
        modelId: server,
      );
      final fromDevice = await repository.find(
        word: alice,
        fileName: file,
        modelId: device,
      );
      expect(fromServer!.facts, '- 新しい事実');
      expect(fromDevice!.facts, '- 端末が書いた事実');
    });

    test('findForWord returns every model rows for the word', () async {
      await write(server, '- サーバが書いた事実');
      await write(device, '- 端末が書いた事実');

      final all = await repository.findForWord(word: alice);

      expect(all.map((e) => e.modelId).toSet(), {server, device});
    });
  });

  group('forced invalidation is scoped to one model', () {
    const alice = 'アリス';
    const server = 'ollama:qwen3:30b';
    const device = 'apple:on-device';

    Future<void> write(String modelId, String fileName) => repository.upsert(
      word: alice,
      fileName: fileName,
      facts: '- 事実',
      contentHash: 'hash-$fileName',
      promptVersion: 1,
      modelId: modelId,
    );

    test('another model rows keep their hash and facts', () async {
      await write(server, '005_ch.txt');
      await write(device, '005_ch.txt');

      await repository.invalidateWord(word: alice, modelId: server);

      final invalidated = await repository.find(
        word: alice,
        fileName: '005_ch.txt',
        modelId: server,
      );
      final untouched = await repository.find(
        word: alice,
        fileName: '005_ch.txt',
        modelId: device,
      );
      expect(invalidated!.contentHash, FactCacheRepository.sentinelHash);
      expect(untouched!.contentHash, 'hash-005_ch.txt');
      expect(untouched.facts, '- 事実');
    });

    test('the model scope and the timestamp bound both apply', () async {
      await write(server, '005_ch.txt');
      await write(device, '005_ch.txt');
      // Local time, matching what upsert writes: the bound is compared as a
      // string, so a UTC mark would sort before every locally-stamped row.
      final mark = DateTime.now();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await write(server, '006_ch.txt');

      await repository.invalidateWord(
        word: alice,
        modelId: server,
        notNewerThan: mark,
      );

      Future<String> hashOf(String file, String model) async =>
          (await repository.find(
            word: alice,
            fileName: file,
            modelId: model,
          ))!.contentHash;

      // Old enough and on the named shelf: invalidated.
      expect(await hashOf('005_ch.txt', server), '');
      // Too new, even on the named shelf: kept.
      expect(await hashOf('006_ch.txt', server), 'hash-006_ch.txt');
      // Old enough but on another shelf: kept.
      expect(await hashOf('005_ch.txt', device), 'hash-005_ch.txt');
    });

    test('deleteAllForWord removes the word rows under every model', () async {
      await write(server, '005_ch.txt');
      await write(device, '005_ch.txt');

      await repository.deleteAllForWord(word: alice);

      expect(await repository.findForWord(word: alice), isEmpty);
    });
  });
}
