import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

void main() {
  late Database db;
  late FactCacheRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    db = await openInMemoryNovelMetadataDb();
    repository = FactCacheRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('FactCacheRepository', () {
    group('upsert / find', () {
      test('inserts then reads back a row by (folder, word, file)', () async {
        await repository.upsert(
          folderName: 'novelA',
          word: 'アリス',
          fileName: '005_ch.txt',
          facts: '- 王国の王女',
          contentHash: 'hash5',
          promptVersion: 1,
        );

        final entry = await repository.find(
          folderName: 'novelA',
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
          folderName: 'novelA',
          word: 'アリス',
          fileName: 'missing.txt',
        );
        expect(entry, isNull);
      });

      test('upsert replaces in place (no duplicate row)', () async {
        await repository.upsert(
          folderName: 'novelA',
          word: 'アリス',
          fileName: '005_ch.txt',
          facts: '- 古い事実',
          contentHash: 'oldhash',
          promptVersion: 1,
        );
        await repository.upsert(
          folderName: 'novelA',
          word: 'アリス',
          fileName: '005_ch.txt',
          facts: '- 新しい事実',
          contentHash: 'newhash',
          promptVersion: 2,
        );

        final rows = await repository.findForWord(
          folderName: 'novelA',
          word: 'アリス',
        );
        expect(rows, hasLength(1), reason: 'colliding key SHALL upsert');
        expect(rows.first.facts, '- 新しい事実');
        expect(rows.first.contentHash, 'newhash');
        expect(rows.first.promptVersion, 2);
      });

      test('findForWord returns only the requested (folder, word)', () async {
        await repository.upsert(
          folderName: 'novelA',
          word: 'アリス',
          fileName: '001.txt',
          facts: 'a',
          contentHash: 'h1',
          promptVersion: 1,
        );
        await repository.upsert(
          folderName: 'novelA',
          word: 'アリス',
          fileName: '002.txt',
          facts: 'b',
          contentHash: 'h2',
          promptVersion: 1,
        );
        await repository.upsert(
          folderName: 'novelA',
          word: 'ボブ',
          fileName: '001.txt',
          facts: 'c',
          contentHash: 'h3',
          promptVersion: 1,
        );
        await repository.upsert(
          folderName: 'novelB',
          word: 'アリス',
          fileName: '001.txt',
          facts: 'd',
          contentHash: 'h4',
          promptVersion: 1,
        );

        final rows = await repository.findForWord(
          folderName: 'novelA',
          word: 'アリス',
        );
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
          folderName: 'novelA',
          word: 'アリス',
          fileName: '001.txt',
          facts: 'a',
          contentHash: 'h1',
          promptVersion: 1,
        );
        await repository.upsert(
          folderName: 'novelA',
          word: 'アリス',
          fileName: '002.txt',
          facts: 'b',
          contentHash: 'h2',
          promptVersion: 1,
        );
        await repository.upsert(
          folderName: 'novelA',
          word: 'ボブ',
          fileName: '001.txt',
          facts: 'c',
          contentHash: 'h3',
          promptVersion: 1,
        );

        await repository.invalidateWord(folderName: 'novelA', word: 'アリス');

        final alice = await repository.findForWord(
          folderName: 'novelA',
          word: 'アリス',
        );
        expect(alice.every((r) => r.contentHash == FactCacheRepository.sentinelHash),
            isTrue);
        expect(FactCacheRepository.sentinelHash, '');

        // Other words must be untouched.
        final bob = await repository.findForWord(
          folderName: 'novelA',
          word: 'ボブ',
        );
        expect(bob.single.contentHash, 'h3');
      });
    });

    group('cascade cleanup', () {
      test('deleteAllForWord removes only that (folder, word) rows', () async {
        await repository.upsert(
          folderName: 'novelA',
          word: 'アリス',
          fileName: '001.txt',
          facts: 'a',
          contentHash: 'h1',
          promptVersion: 1,
        );
        await repository.upsert(
          folderName: 'novelA',
          word: 'ボブ',
          fileName: '001.txt',
          facts: 'b',
          contentHash: 'h2',
          promptVersion: 1,
        );
        await repository.upsert(
          folderName: 'novelB',
          word: 'アリス',
          fileName: '001.txt',
          facts: 'c',
          contentHash: 'h3',
          promptVersion: 1,
        );

        await repository.deleteAllForWord(folderName: 'novelA', word: 'アリス');

        expect(
          await repository.findForWord(folderName: 'novelA', word: 'アリス'),
          isEmpty,
        );
        expect(
          await repository.findForWord(folderName: 'novelA', word: 'ボブ'),
          hasLength(1),
        );
        expect(
          await repository.findForWord(folderName: 'novelB', word: 'アリス'),
          hasLength(1),
        );
      });

      test('deleteByFolderName removes every row for the folder', () async {
        await repository.upsert(
          folderName: 'novelA',
          word: 'アリス',
          fileName: '001.txt',
          facts: 'a',
          contentHash: 'h1',
          promptVersion: 1,
        );
        await repository.upsert(
          folderName: 'novelA',
          word: 'ボブ',
          fileName: '002.txt',
          facts: 'b',
          contentHash: 'h2',
          promptVersion: 1,
        );
        await repository.upsert(
          folderName: 'novelB',
          word: 'アリス',
          fileName: '001.txt',
          facts: 'c',
          contentHash: 'h3',
          promptVersion: 1,
        );

        await repository.deleteByFolderName('novelA');

        expect(
          await repository.findForWord(folderName: 'novelA', word: 'アリス'),
          isEmpty,
        );
        expect(
          await repository.findForWord(folderName: 'novelA', word: 'ボブ'),
          isEmpty,
        );
        expect(
          await repository.findForWord(folderName: 'novelB', word: 'アリス'),
          hasLength(1),
        );
      });
    });
  });
}
