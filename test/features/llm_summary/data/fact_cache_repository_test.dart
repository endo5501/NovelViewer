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

  group('FactCacheRepository', () {
    group('upsert / find', () {
      test('inserts then reads back a row by (word, file)', () async {
        await repository.upsert(
          word: 'アリス',
          fileName: '005_ch.txt',
          facts: '- 王国の王女',
          contentHash: 'hash5',
          promptVersion: 1,
        );

        final entry = await repository.find(
          word: 'アリス',
          fileName: '005_ch.txt',
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
        );
        await repository.upsert(
          word: 'アリス',
          fileName: '005_ch.txt',
          facts: '- 新しい事実',
          contentHash: 'newhash',
          promptVersion: 2,
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
        );
        await repository.upsert(
          word: 'アリス',
          fileName: '002.txt',
          facts: 'b',
          contentHash: 'h2',
          promptVersion: 1,
        );
        await repository.upsert(
          word: 'ボブ',
          fileName: '001.txt',
          facts: 'c',
          contentHash: 'h3',
          promptVersion: 1,
        );

        final rows = await repository.findForWord(word: 'アリス');
        expect(rows, hasLength(2));
        expect(
          rows.map((r) => r.fileName).toSet(),
          {'001.txt', '002.txt'},
        );
      });
    });

    group('invalidateWord', () {
      test('sets content_hash to the empty-string sentinel for the word',
          () async {
        await repository.upsert(
          word: 'アリス',
          fileName: '001.txt',
          facts: 'a',
          contentHash: 'h1',
          promptVersion: 1,
        );
        await repository.upsert(
          word: 'アリス',
          fileName: '002.txt',
          facts: 'b',
          contentHash: 'h2',
          promptVersion: 1,
        );
        await repository.upsert(
          word: 'ボブ',
          fileName: '001.txt',
          facts: 'c',
          contentHash: 'h3',
          promptVersion: 1,
        );

        await repository.invalidateWord(word: 'アリス');

        final alice = await repository.findForWord(word: 'アリス');
        expect(alice.every((r) => r.contentHash == FactCacheRepository.sentinelHash),
            isTrue);
        expect(FactCacheRepository.sentinelHash, '');

        // Other words must be untouched.
        final bob = await repository.findForWord(word: 'ボブ');
        expect(bob.single.contentHash, 'h3');
      });

      Future<void> seed(String fileName, String updatedAt) async {
        await repository.upsert(
          word: 'アリス',
          fileName: fileName,
          facts: 'facts-$fileName',
          contentHash: 'hash-$fileName',
          promptVersion: 1,
        );
        await db.update(
          'fact_cache',
          {'updated_at': updatedAt},
          where: 'word = ? AND file_name = ?',
          whereArgs: ['アリス', fileName],
        );
      }

      Future<String?> hashOf(String fileName) async =>
          (await repository.find(word: 'アリス', fileName: fileName))
              ?.contentHash;

      test('rows newer than the reference timestamp are preserved', () async {
        await seed('old.txt', '2026-08-01T00:00:00.000Z');
        await seed('new.txt', '2026-08-03T00:00:00.000Z');

        await repository.invalidateWord(
          word: 'アリス',
          notNewerThan: DateTime.utc(2026, 8, 2),
        );

        expect(await hashOf('old.txt'), FactCacheRepository.sentinelHash);
        expect(await hashOf('new.txt'), 'hash-new.txt');
      });

      test('a row at exactly the reference timestamp is invalidated', () async {
        await seed('exact.txt', '2026-08-02T00:00:00.000Z');

        await repository.invalidateWord(
          word: 'アリス',
          notNewerThan: DateTime.utc(2026, 8, 2),
        );

        expect(await hashOf('exact.txt'), FactCacheRepository.sentinelHash);
      });

      test('facts of a preserved row are left intact', () async {
        await seed('new.txt', '2026-08-03T00:00:00.000Z');

        await repository.invalidateWord(
          word: 'アリス',
          notNewerThan: DateTime.utc(2026, 8, 2),
        );

        final row = await repository.find(word: 'アリス', fileName: 'new.txt');
        expect(row!.facts, 'facts-new.txt');
      });

      test('omitting the reference timestamp invalidates every row', () async {
        await seed('old.txt', '2026-08-01T00:00:00.000Z');
        await seed('new.txt', '2026-08-03T00:00:00.000Z');

        await repository.invalidateWord(word: 'アリス');

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
        );
        await repository.upsert(
          word: 'ボブ',
          fileName: '001.txt',
          facts: 'b',
          contentHash: 'h2',
          promptVersion: 1,
        );

        await repository.deleteAllForWord(word: 'アリス');

        expect(await repository.findForWord(word: 'アリス'), isEmpty);
        expect(await repository.findForWord(word: 'ボブ'), hasLength(1));
      });
    });
  });
}
