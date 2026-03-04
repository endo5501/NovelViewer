import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_database.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late TtsDictionaryDatabase database;
  late TtsDictionaryRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('tts_dictionary_repo_test_');
    database = TtsDictionaryDatabase(tempDir.path);
    repository = TtsDictionaryRepository(database);
  });

  tearDown(() async {
    await database.close();
    tempDir.deleteSync(recursive: true);
  });

  group('TtsDictionaryRepository', () {
    group('addEntry', () {
      test('returns a positive id after inserting', () async {
        final id = await repository.addEntry('山田太郎', 'やまだたろう');
        expect(id, greaterThan(0));
      });

      test('throws on duplicate surface', () async {
        await repository.addEntry('山田太郎', 'やまだたろう');
        expect(
          () => repository.addEntry('山田太郎', 'べつのよみ'),
          throwsA(anything),
        );
      });
    });

    group('getAllEntries', () {
      test('returns empty list when no entries exist', () async {
        final entries = await repository.getAllEntries();
        expect(entries, isEmpty);
      });

      test('returns all inserted entries', () async {
        await repository.addEntry('山田太郎', 'やまだたろう');
        await repository.addEntry('エルリック', 'えるりっく');

        final entries = await repository.getAllEntries();
        expect(entries.length, 2);
        expect(entries.map((e) => e.surface),
            containsAll(['山田太郎', 'エルリック']));
      });

      test('entry has correct surface and reading', () async {
        await repository.addEntry('シャルロット', 'しゃるろっと');

        final entries = await repository.getAllEntries();
        expect(entries.first.surface, 'シャルロット');
        expect(entries.first.reading, 'しゃるろっと');
      });
    });

    group('updateEntry', () {
      test('updates reading for existing entry', () async {
        final id = await repository.addEntry('山田太郎', 'やまだたろう');
        await repository.updateEntry(id, '山田太郎', 'やまだ・たろう');

        final entries = await repository.getAllEntries();
        expect(entries.first.reading, 'やまだ・たろう');
      });
    });

    group('deleteEntry', () {
      test('removes entry by id', () async {
        final id = await repository.addEntry('山田太郎', 'やまだたろう');
        await repository.deleteEntry(id);

        final entries = await repository.getAllEntries();
        expect(entries, isEmpty);
      });
    });
  });

  group('applyDictionary', () {
    test('returns text unchanged when dictionary is empty', () async {
      final result = await repository.applyDictionary('山田太郎は強い');
      expect(result, '山田太郎は強い');
    });

    test('replaces surface with reading', () async {
      await repository.addEntry('山田太郎', 'やまだたろう');

      final result = await repository.applyDictionary('山田太郎は強い');
      expect(result, 'やまだたろうは強い');
    });

    test('longest match wins over shorter match', () async {
      await repository.addEntry('山田', 'やまだ');
      await repository.addEntry('山田太郎', 'やまだたろう');

      final result = await repository.applyDictionary('山田太郎は強い');
      expect(result, 'やまだたろうは強い');
    });

    test('applies multiple entries in one pass', () async {
      await repository.addEntry('シャルロット', 'しゃるろっと');
      await repository.addEntry('アルベルト', 'あるべると');

      final result =
          await repository.applyDictionary('シャルロット姫とアルベルト王');
      expect(result, 'しゃるろっと姫とあるべると王');
    });

    test('text with no matching entries is returned unchanged', () async {
      await repository.addEntry('山田太郎', 'やまだたろう');

      final result = await repository.applyDictionary('エルリックは勇者だ');
      expect(result, 'エルリックは勇者だ');
    });

    test('same-length entries have stable order by id', () async {
      await repository.addEntry('aa', 'XX');
      await repository.addEntry('bb', 'YY');

      final result1 = await repository.applyDictionary('aabb');
      final result2 = await repository.applyDictionary('aabb');
      expect(result1, result2);
    });
  });

  group('addEntry / updateEntry validation', () {
    test('addEntry rejects empty surface', () async {
      expect(() => repository.addEntry('', 'よみ'), throwsA(anything));
    });

    test('addEntry rejects empty reading', () async {
      expect(() => repository.addEntry('表記', ''), throwsA(anything));
    });

    test('updateEntry rejects empty surface', () async {
      final id = await repository.addEntry('表記', 'よみ');
      expect(() => repository.updateEntry(id, '', 'よみ'), throwsA(anything));
    });

    test('updateEntry rejects empty reading', () async {
      final id = await repository.addEntry('表記', 'よみ');
      expect(() => repository.updateEntry(id, '表記', ''), throwsA(anything));
    });
  });

  group('applyDictionaryWithEntries defensive behavior', () {
    test('skips empty surface entries without infinite loop', () {
      final entries = [
        const TtsDictionaryEntry(id: 1, surface: '', reading: 'X'),
        const TtsDictionaryEntry(id: 2, surface: 'abc', reading: 'ABC'),
      ];
      final result = TtsDictionaryRepository.applyDictionaryWithEntries(
          entries, 'xabcx');
      expect(result, 'xABCx');
    });
  });
}
