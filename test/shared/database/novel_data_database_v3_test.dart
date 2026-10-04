import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/database/novel_data_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Stored SQL of `word_summaries` and its index, keyed by name, so two
/// databases' definitions of the rebuilt table can be compared exactly.
Future<Map<String, String?>> _wordSummariesSql(Database db) async {
  final rows = await db.rawQuery(
    'SELECT name, sql FROM sqlite_master '
    "WHERE name LIKE '%word_summaries%' ORDER BY name",
  );
  return {for (final r in rows) r['name'] as String: r['sql'] as String?};
}

/// A `novel_data.db` at v2, written out by hand: the shape a v2 file on a
/// reader's disk has, which the current schema helper can no longer produce.
Future<void> _seedV2(String folderPath) async {
  final db = await databaseFactory.openDatabase(
    '$folderPath${Platform.pathSeparator}novel_data.db',
    options: OpenDatabaseOptions(
      version: 2,
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
            model_id TEXT NOT NULL CHECK (model_id <> ''),
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE UNIQUE INDEX idx_fact_cache_unique
          ON fact_cache(word, file_name, model_id)
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
    'updated_at': 't1',
  });
  await db.insert('word_summaries', {
    'word': 'ボブ',
    'covered_up_to_episode': 5,
    'summary': '鍛冶屋。',
    'source_file': null,
    'created_at': 't2',
    'updated_at': 't3',
  });
  await db.insert('fact_cache', {
    'word': 'アリス',
    'file_name': '005.txt',
    'facts': '- 事実',
    'content_hash': 'h',
    'prompt_version': 1,
    'model_id': 'm',
    'updated_at': 't0',
  });
  await db.insert('bookmarks', {
    'file_name': '010.txt',
    'line_number': 42,
    'created_at': 't0',
  });
  await db.close();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('novel_data_db_v3_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('the current novel_data.db version is 3', () {
    expect(NovelDataDatabase.currentVersion, 3);
  });

  test('a fresh word_summaries carries a reference_sources column', () async {
    final wrapper = NovelDataDatabase(tempDir.path);
    addTearDown(wrapper.close);
    final db = await wrapper.database;

    final columns = await db.rawQuery('PRAGMA table_info(word_summaries)');
    expect(columns.map((c) => c['name']), contains('reference_sources'));
  });

  test('v2 → v3 keeps every summary row with its values', () async {
    await _seedV2(tempDir.path);

    final wrapper = NovelDataDatabase(tempDir.path);
    addTearDown(wrapper.close);
    final db = await wrapper.database;

    expect(await db.getVersion(), 3);
    final rows = await db.query('word_summaries', orderBy: 'word');
    expect(rows, hasLength(2));
    final alice = rows.firstWhere((r) => r['word'] == 'アリス');
    expect(alice['covered_up_to_episode'], 30);
    expect(alice['summary'], '騎士団の副長。');
    expect(alice['source_file'], '030.txt');
    expect(alice['created_at'], 't0');
    expect(alice['updated_at'], 't1');
    expect(alice['reference_sources'], isNull);
    final bob = rows.firstWhere((r) => r['word'] == 'ボブ');
    expect(bob['source_file'], isNull);
  });

  test('v2 → v3 leaves fact_cache and bookmarks alone', () async {
    await _seedV2(tempDir.path);

    final wrapper = NovelDataDatabase(tempDir.path);
    addTearDown(wrapper.close);
    final db = await wrapper.database;

    final facts = await db.query('fact_cache');
    expect(facts.single['facts'], '- 事実');
    expect(await db.query('bookmarks'), hasLength(1));
  });

  test('the upgraded word_summaries matches a fresh one exactly', () async {
    await _seedV2(tempDir.path);
    final upgraded = NovelDataDatabase(tempDir.path);
    addTearDown(upgraded.close);
    final upgradedSql = await _wordSummariesSql(await upgraded.database);

    final freshDir = Directory.systemTemp.createTempSync(
      'novel_data_v3_fresh_',
    );
    addTearDown(() {
      if (freshDir.existsSync()) freshDir.deleteSync(recursive: true);
    });
    final fresh = NovelDataDatabase(freshDir.path);
    addTearDown(fresh.close);
    final freshSql = await _wordSummariesSql(await fresh.database);

    expect(upgradedSql, freshSql);
  });

  test('the unique key still holds after the upgrade', () async {
    await _seedV2(tempDir.path);
    final wrapper = NovelDataDatabase(tempDir.path);
    addTearDown(wrapper.close);
    final db = await wrapper.database;

    await expectLater(
      db.insert('word_summaries', {
        'word': 'アリス',
        'covered_up_to_episode': 30,
        'summary': 'dup',
        'created_at': 't',
        'updated_at': 't',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
