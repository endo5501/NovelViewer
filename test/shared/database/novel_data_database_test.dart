import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/database/novel_data_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Returns the set of column names for [table] in [db].
Future<Set<String>> _columns(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.map((r) => r['name'] as String).toSet();
}

/// Returns the columns of [index], in index order.
Future<List<String>> _indexColumns(Database db, String index) async {
  final rows = await db.rawQuery('PRAGMA index_info($index)');
  final sorted = [...rows]
    ..sort((a, b) => (a['seqno'] as int).compareTo(b['seqno'] as int));
  return sorted.map((r) => r['name'] as String).toList();
}

/// Returns the stored SQL of the `fact_cache` table and its index, keyed by
/// name, so two databases' definitions of it can be compared exactly.
///
/// Scoped to `fact_cache` because that is what the upgrade rebuilds. The other
/// tables carry whatever formatting the database was originally created with,
/// and comparing those would only measure the test fixture's own indentation.
Future<Map<String, String?>> _factCacheSql(Database db) async {
  final rows = await db.rawQuery(
    'SELECT name, sql FROM sqlite_master '
    "WHERE name LIKE '%fact_cache%' ORDER BY name",
  );
  return {for (final r in rows) r['name'] as String: r['sql'] as String?};
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
        File(
          '${tempDir.path}${Platform.pathSeparator}novel_data.db',
        ).existsSync(),
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
        '(word, file_name, model_id)', () async {
      final wrapper = NovelDataDatabase(tempDir.path);
      addTearDown(wrapper.close);
      final db = await wrapper.database;

      final cols = await _columns(db, 'fact_cache');
      expect(cols, contains('word'));
      expect(cols, contains('file_name'));
      expect(cols, contains('facts'));
      expect(cols, contains('content_hash'));
      expect(cols, contains('prompt_version'));
      expect(cols, contains('model_id'));
      expect(cols, isNot(contains('folder_name')));

      expect(await _indexColumns(db, 'idx_fact_cache_unique'), [
        'word',
        'file_name',
        'model_id',
      ]);

      Future<void> upsert(String facts, String modelId) => db.rawInsert(
        '''
            INSERT INTO fact_cache
              (word, file_name, facts, content_hash, prompt_version,
               model_id, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(word, file_name, model_id) DO UPDATE SET
              facts = excluded.facts
            ''',
        ['アリス', '005.txt', facts, 'h', 1, modelId, 't0'],
      );
      await upsert('a', 'ollama:m');
      await upsert('b', 'ollama:m');

      final sameModel = await db.query('fact_cache');
      expect(sameModel, hasLength(1));
      expect(sameModel.first['facts'], 'b');

      // A different model is a different shelf, not a replacement.
      await upsert('c', 'apple:on-device');
      expect(await db.query('fact_cache'), hasLength(2));
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
      await db.insert('bookmarks', {
        'file_name': '010.txt',
        'line_number': 42,
        'created_at': 't1',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      final rows = await db.query('bookmarks');
      expect(rows, hasLength(1));
    });
  });

  group('NovelDataDatabase open failure', () {
    test(
      'a corrupt file is preserved (not deleted) and the error rethrown',
      () async {
        // Plant a non-SQLite file where the DB is expected.
        final dbFile = File(
          '${tempDir.path}${Platform.pathSeparator}novel_data.db',
        );
        dbFile.writeAsStringSync('this is not a sqlite database');

        final wrapper = NovelDataDatabase(tempDir.path);
        addTearDown(wrapper.close);

        await expectLater(wrapper.database, throwsA(anything));
        // deleteOnFailure:false → the file must remain for manual recovery.
        expect(dbFile.existsSync(), isTrue);
      },
    );
  });

  group('NovelDataDatabase connection gate', () {
    test(
      'concurrent reads share a single open handle (in-flight sharing)',
      () async {
        final wrapper = NovelDataDatabase(tempDir.path);
        addTearDown(wrapper.close);

        final results = await Future.wait([wrapper.database, wrapper.database]);
        expect(identical(results[0], results[1]), isTrue);
      },
    );

    test('reopens with a fresh handle after close', () async {
      final wrapper = NovelDataDatabase(tempDir.path);
      addTearDown(wrapper.close);

      final db1 = await wrapper.database;
      await wrapper.close();
      final db2 = await wrapper.database;
      expect(identical(db1, db2), isFalse);
    });
  });

  group('NovelDataDatabase upgrade from the pre-model-identity schema', () {
    /// The historical v1 `fact_cache`: no `model_id`, keyed by two columns.
    /// Hand-written on purpose — the definition no longer exists in production
    /// code, so seeding an old database is the one thing that cannot go
    /// through the current schema helper.
    Future<void> seedV1(String folderPath) async {
      final db = await databaseFactory.openDatabase(
        '$folderPath${Platform.pathSeparator}novel_data.db',
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE word_summaries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
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
              ON word_summaries(word, covered_up_to_episode)
            ''');
            await db.execute('''
              CREATE TABLE fact_cache (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
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
              ON fact_cache(word, file_name)
            ''');
            await db.execute('''
              CREATE TABLE bookmarks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_name TEXT NOT NULL,
                line_number INTEGER,
                created_at TEXT NOT NULL,
                UNIQUE(file_name, line_number)
              )
            ''');
          },
        ),
      );
      await db.insert('word_summaries', {
        'word': 'アリス',
        'covered_up_to_episode': 30,
        'summary': '騎士団の副長。',
        'source_file': '030.txt',
        'created_at': 't0',
        'updated_at': 't0',
      });
      await db.insert('fact_cache', {
        'word': 'アリス',
        'file_name': '005.txt',
        'facts': '- 誰が書いたか分からない事実',
        'content_hash': 'h',
        'prompt_version': 1,
        'updated_at': 't0',
      });
      await db.insert('bookmarks', {
        'file_name': '010.txt',
        'line_number': 42,
        'created_at': 't0',
      });
      await db.close();
    }

    test('the production upgrade path rebuilds fact_cache', () async {
      await seedV1(tempDir.path);

      final wrapper = NovelDataDatabase(tempDir.path);
      addTearDown(wrapper.close);
      final db = await wrapper.database;

      expect(await _columns(db, 'fact_cache'), contains('model_id'));
      expect(await _indexColumns(db, 'idx_fact_cache_unique'), [
        'word',
        'file_name',
        'model_id',
      ]);
    });

    test('rows of unknown provenance do not survive the upgrade', () async {
      // A row with no model identity could never be found by any client and
      // could never be replaced by an upsert, so keeping it would leave
      // residue that surfaces in the inspector forever.
      await seedV1(tempDir.path);

      final wrapper = NovelDataDatabase(tempDir.path);
      addTearDown(wrapper.close);
      final db = await wrapper.database;

      expect(await db.query('fact_cache'), isEmpty);
    });

    test('the upgrade leaves summaries and bookmarks alone', () async {
      await seedV1(tempDir.path);

      final wrapper = NovelDataDatabase(tempDir.path);
      addTearDown(wrapper.close);
      final db = await wrapper.database;

      final summaries = await db.query('word_summaries');
      expect(summaries, hasLength(1));
      expect(summaries.first['summary'], '騎士団の副長。');
      expect(await db.query('bookmarks'), hasLength(1));
    });

    test(
      'the rebuilt fact_cache is identical to a freshly created one',
      () async {
        // SQLite requires a DEFAULT clause to add a NOT NULL column, which would
        // leave the upgraded table's SQL differing from a fresh one. Rebuilding
        // the table is what keeps the two paths from drifting.
        await seedV1(tempDir.path);
        final upgraded = NovelDataDatabase(tempDir.path);
        addTearDown(upgraded.close);
        final upgradedSql = await _factCacheSql(await upgraded.database);

        final freshDir = Directory.systemTemp.createTempSync(
          'novel_data_fresh_',
        );
        addTearDown(() {
          if (freshDir.existsSync()) freshDir.deleteSync(recursive: true);
        });
        final fresh = NovelDataDatabase(freshDir.path);
        addTearDown(fresh.close);
        final freshSql = await _factCacheSql(await fresh.database);

        expect(upgradedSql, freshSql);
      },
    );
  });

  group('NovelDataDatabase downgrade', () {
    test('opening at an older version is refused, not stamped down', () async {
      // sqflite skips an unsupplied onDowngrade and then writes the requested
      // version anyway, leaving a database whose schema and user_version
      // disagree. A build that believed it held the older schema would emit
      // an upsert naming a unique key the table no longer has, and fail on
      // every write. Refusing the open is the honest outcome.
      final wrapper = NovelDataDatabase(tempDir.path);
      final db = await wrapper.database;
      final atCurrent = await db.getVersion();
      await wrapper.close();

      final path = '${tempDir.path}${Platform.pathSeparator}novel_data.db';
      await expectLater(
        databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: atCurrent - 1,
            singleInstance: false,
            onCreate: (db, _) => NovelDataDatabase.createCurrentSchema(db),
            onUpgrade: NovelDataDatabase.upgradeToCurrent,
            onDowngrade: NovelDataDatabase.refuseDowngrade,
          ),
        ),
        throwsA(anything),
      );

      // The refusal must not have moved the stamp.
      final reopened = NovelDataDatabase(tempDir.path);
      addTearDown(reopened.close);
      expect(await (await reopened.database).getVersion(), atCurrent);
    });
  });
}
