import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_data_migrator.dart';
import 'package:novel_viewer/shared/database/novel_data_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds an in-memory `novel_metadata.db` at the v8 shape (the three per-novel
/// tables still present) so the v8→v9 migration can be exercised in isolation.
Future<Database> _openV8Global() {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      singleInstance: false,
      version: 8,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE word_summaries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            folder_name TEXT NOT NULL,
            word TEXT NOT NULL,
            covered_up_to_episode INTEGER NOT NULL,
            summary TEXT NOT NULL,
            source_file TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE fact_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            folder_name TEXT NOT NULL,
            word TEXT NOT NULL,
            file_name TEXT NOT NULL,
            facts TEXT NOT NULL,
            content_hash TEXT NOT NULL,
            prompt_version INTEGER NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            novel_id TEXT NOT NULL,
            file_name TEXT NOT NULL,
            line_number INTEGER,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE reading_progress (
            novel_id TEXT NOT NULL PRIMARY KEY,
            file_name TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    ),
  );
}

Future<bool> _tableExists(Database db, String name) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    [name],
  );
  return rows.isNotEmpty;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database global;
  late Directory libRoot;

  setUp(() async {
    global = await _openV8Global();
    libRoot = Directory.systemTemp.createTempSync('migration_v9_');
  });

  tearDown(() async {
    await global.close();
    if (libRoot.existsSync()) libRoot.deleteSync(recursive: true);
  });

  // singleInstance:false so each open is an independent connection that reads
  // the committed file — mirroring production, where a re-run after a crash
  // opens the folder db fresh (new process) and sees prior-committed rows.
  Future<Database> openFolderDb(String folder) =>
      databaseFactoryFfi.openDatabase(
        p.join(libRoot.path, folder, NovelDataDatabase.databaseName),
        options: OpenDatabaseOptions(
          singleInstance: false,
          version: 1,
          onCreate: (db, _) => NovelDataDatabase.createCurrentSchema(db),
        ),
      );

  /// A migrator that routes [present] folders to real `novel_data.db` files
  /// under [libRoot] (so they persist after the migration closes them and can
  /// be reopened for assertions); any other folder resolves to null (orphan).
  NovelDataMigrator buildMigrator(Set<String> present) {
    for (final folder in present) {
      Directory(p.join(libRoot.path, folder)).createSync(recursive: true);
    }
    return NovelDataMigrator(
      resolveFolderPath: (folder) =>
          present.contains(folder) ? p.join(libRoot.path, folder) : null,
      openNovelDataDb: (folderPath) => databaseFactoryFfi.openDatabase(
        p.join(folderPath, NovelDataDatabase.databaseName),
        options: OpenDatabaseOptions(
          singleInstance: false,
          version: 1,
          onCreate: (db, _) => NovelDataDatabase.createCurrentSchema(db),
        ),
      ),
    );
  }

  test('copies each folder\'s rows into its novel_data.db then drops globals',
      () async {
    await global.insert('word_summaries', {
      'folder_name': 'novelA',
      'word': 'アリス',
      'covered_up_to_episode': 30,
      'summary': '要約',
      'source_file': '030.txt',
      'created_at': 't',
      'updated_at': 't',
    });
    await global.insert('fact_cache', {
      'folder_name': 'novelA',
      'word': 'アリス',
      'file_name': '030.txt',
      'facts': '- 事実',
      'content_hash': 'h',
      'prompt_version': 1,
      'updated_at': 't',
    });
    await global.insert('bookmarks', {
      'novel_id': 'novelA',
      'file_name': '030.txt',
      'line_number': 5,
      'created_at': 't',
    });

    final migrator = buildMigrator({'novelA'});
    await migrateV8ToV9(global, migrator);

    final folderDb = await openFolderDb('novelA');
    addTearDown(folderDb.close);
    final ws = await folderDb.query('word_summaries');
    expect(ws, hasLength(1));
    expect(ws.first['word'], 'アリス');
    expect(ws.first.containsKey('folder_name'), isFalse);

    final fc = await folderDb.query('fact_cache');
    expect(fc, hasLength(1));
    expect(fc.first['file_name'], '030.txt');

    final bm = await folderDb.query('bookmarks');
    expect(bm, hasLength(1));
    expect(bm.first['line_number'], 5);

    // Global per-novel tables dropped; reading_progress retained.
    expect(await _tableExists(global, 'word_summaries'), isFalse);
    expect(await _tableExists(global, 'fact_cache'), isFalse);
    expect(await _tableExists(global, 'bookmarks'), isFalse);
    expect(await _tableExists(global, 'reading_progress'), isTrue);
  });

  test('discards rows for folders missing on disk (orphans)', () async {
    await global.insert('word_summaries', {
      'folder_name': 'gone',
      'word': 'アリス',
      'covered_up_to_episode': 1,
      'summary': 's',
      'source_file': null,
      'created_at': 't',
      'updated_at': 't',
    });

    // 'gone' is not present → resolves to null → discarded.
    final migrator = buildMigrator({});
    await migrateV8ToV9(global, migrator);

    // Tables still dropped; nothing thrown.
    expect(await _tableExists(global, 'word_summaries'), isFalse);
  });

  test('re-running over a partially-copied folder does not duplicate (idempotent)',
      () async {
    await global.insert('word_summaries', {
      'folder_name': 'novelA',
      'word': 'アリス',
      'covered_up_to_episode': 30,
      'summary': '要約',
      'source_file': '030.txt',
      'created_at': 't',
      'updated_at': 't',
    });

    final migrator = buildMigrator({'novelA'});
    // Simulate a prior interrupted run that already copied the row.
    final pre = await openFolderDb('novelA');
    await pre.insert('word_summaries', {
      'word': 'アリス',
      'covered_up_to_episode': 30,
      'summary': '要約',
      'source_file': '030.txt',
      'created_at': 't',
      'updated_at': 't',
    });
    await pre.close();

    await migrateV8ToV9(global, migrator);

    final folderDb = await openFolderDb('novelA');
    addTearDown(folderDb.close);
    final ws = await folderDb.query('word_summaries');
    expect(ws, hasLength(1), reason: 'INSERT OR IGNORE dedups the re-copy');
  });

  test('re-running does not duplicate whole-file (NULL line) bookmarks',
      () async {
    await global.insert('bookmarks', {
      'novel_id': 'novelA',
      'file_name': '001.txt',
      'line_number': null,
      'created_at': 't',
    });

    final migrator = buildMigrator({'novelA'});
    // Simulate a prior interrupted run that already copied the NULL-line
    // bookmark into the folder db.
    final pre = await openFolderDb('novelA');
    await pre.insert('bookmarks', {
      'file_name': '001.txt',
      'line_number': null,
      'created_at': 't',
    });
    await pre.close();

    await migrateV8ToV9(global, migrator);

    final folderDb = await openFolderDb('novelA');
    addTearDown(folderDb.close);
    final bm = await folderDb.query('bookmarks');
    expect(bm, hasLength(1),
        reason: 'the clear-then-copy migration SHALL not append a duplicate '
            'whole-file (NULL line) bookmark on re-run');
  });
}
