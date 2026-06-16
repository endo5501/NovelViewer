import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/database/novel_data_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Returns the set of column names for [table] in [db].
Future<Set<String>> _columns(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.map((r) => r['name'] as String).toSet();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('novel_data_db_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('NovelDataDatabase schema', () {
    test('creates novel_data.db file under the folder', () async {
      final wrapper = NovelDataDatabase(tempDir.path);
      addTearDown(wrapper.close);
      await wrapper.database;

      expect(
        File('${tempDir.path}${Platform.pathSeparator}novel_data.db')
            .existsSync(),
        isTrue,
      );
    });

    test('word_summaries has no folder_name column and is keyed by '
        '(word, covered_up_to_episode)', () async {
      final wrapper = NovelDataDatabase(tempDir.path);
      addTearDown(wrapper.close);
      final db = await wrapper.database;

      final cols = await _columns(db, 'word_summaries');
      expect(cols, contains('word'));
      expect(cols, contains('covered_up_to_episode'));
      expect(cols, contains('summary'));
      expect(cols, contains('source_file'));
      expect(cols, isNot(contains('folder_name')));

      // Upsert on the unique key replaces in place (no duplicate rows).
      Future<void> save(String summary) => db.rawInsert(
            '''
            INSERT INTO word_summaries
              (word, covered_up_to_episode, summary, source_file,
               created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(word, covered_up_to_episode) DO UPDATE SET
              summary = excluded.summary,
              updated_at = excluded.updated_at
            ''',
            ['アリス', 30, summary, '030.txt', 't0', 't0'],
          );
      await save('first');
      await save('second');

      final rows = await db.query('word_summaries');
      expect(rows, hasLength(1));
      expect(rows.first['summary'], 'second');
    });

    test('fact_cache has no folder_name column and is keyed by '
        '(word, file_name)', () async {
      final wrapper = NovelDataDatabase(tempDir.path);
      addTearDown(wrapper.close);
      final db = await wrapper.database;

      final cols = await _columns(db, 'fact_cache');
      expect(cols, contains('word'));
      expect(cols, contains('file_name'));
      expect(cols, contains('facts'));
      expect(cols, contains('content_hash'));
      expect(cols, contains('prompt_version'));
      expect(cols, isNot(contains('folder_name')));

      Future<void> upsert(String facts) => db.rawInsert(
            '''
            INSERT INTO fact_cache
              (word, file_name, facts, content_hash, prompt_version, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(word, file_name) DO UPDATE SET
              facts = excluded.facts
            ''',
            ['アリス', '005.txt', facts, 'h', 1, 't0'],
          );
      await upsert('a');
      await upsert('b');

      final rows = await db.query('fact_cache');
      expect(rows, hasLength(1));
      expect(rows.first['facts'], 'b');
    });

    test('bookmarks has no novel_id column and is keyed by '
        '(file_name, line_number)', () async {
      final wrapper = NovelDataDatabase(tempDir.path);
      addTearDown(wrapper.close);
      final db = await wrapper.database;

      final cols = await _columns(db, 'bookmarks');
      expect(cols, contains('file_name'));
      expect(cols, contains('line_number'));
      expect(cols, contains('created_at'));
      expect(cols, isNot(contains('novel_id')));
      expect(cols, isNot(contains('file_path')));

      await db.insert('bookmarks', {
        'file_name': '010.txt',
        'line_number': 42,
        'created_at': 't0',
      });
      await db.insert(
        'bookmarks',
        {'file_name': '010.txt', 'line_number': 42, 'created_at': 't1'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final rows = await db.query('bookmarks');
      expect(rows, hasLength(1));
    });
  });

  group('NovelDataDatabase open failure', () {
    test('a corrupt file is preserved (not deleted) and the error rethrown',
        () async {
      // Plant a non-SQLite file where the DB is expected.
      final dbFile =
          File('${tempDir.path}${Platform.pathSeparator}novel_data.db');
      dbFile.writeAsStringSync('this is not a sqlite database');

      final wrapper = NovelDataDatabase(tempDir.path);
      addTearDown(wrapper.close);

      await expectLater(wrapper.database, throwsA(anything));
      // deleteOnFailure:false → the file must remain for manual recovery.
      expect(dbFile.existsSync(), isTrue);
    });
  });
}
