import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Seeds the sync tables of a `novel_metadata.db` at the v13 schema, written
/// out by hand so the test pins what a v13 file on a reader's disk holds. The
/// v13 → v14 step only touches these tables.
Future<void> _seedV13(String dbPath) async {
  final db = await databaseFactoryFfi.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 13,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE sync_remote_progress (
            device_id TEXT NOT NULL,
            novel_id TEXT NOT NULL,
            device_name TEXT NOT NULL,
            episode INTEGER NOT NULL,
            file_name TEXT NOT NULL,
            body_offset INTEGER NOT NULL,
            body_hash TEXT,
            read_at TEXT NOT NULL,
            PRIMARY KEY (device_id, novel_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_own_progress (
            novel_id TEXT NOT NULL PRIMARY KEY,
            episode INTEGER NOT NULL,
            file_name TEXT NOT NULL,
            body_offset INTEGER NOT NULL,
            body_hash TEXT,
            read_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_handled (
            novel_id TEXT NOT NULL PRIMARY KEY,
            handled_read_at TEXT NOT NULL
          )
        ''');
        await db.insert('sync_remote_progress', {
          'device_id': 'pad',
          'novel_id': 'narou_n1',
          'device_name': 'iPad',
          'episode': 5,
          'file_name': '005.txt',
          'body_offset': 10,
          'body_hash': 'h',
          'read_at': '2026-11-01T00:00:00.000Z',
        });
        await db.insert('sync_own_progress', {
          'novel_id': 'narou_n2',
          'episode': 2,
          'file_name': '002.txt',
          'body_offset': 20,
          'body_hash': null,
          'read_at': '2026-11-02T00:00:00.000Z',
        });
      },
    ),
  );
  await db.close();
}

/// `{column name: (type, notnull)}` of [table].
Future<Map<String, (String, int)>> _columns(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return {
    for (final row in rows)
      row['name'] as String: (row['type'] as String, row['notnull'] as int),
  };
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('migration_v14_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test(
    'a fresh database has nullable url and title on both sync tables',
    () async {
      final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
      try {
        final db = await novelDatabase.database;
        for (final table in ['sync_remote_progress', 'sync_own_progress']) {
          final columns = await _columns(db, table);
          expect(columns['url'], ('TEXT', 0), reason: table);
          expect(columns['title'], ('TEXT', 0), reason: table);
        }
      } finally {
        await novelDatabase.close();
      }
    },
  );

  test('v13 → v14 adds the columns as NULL and keeps every row', () async {
    await _seedV13(p.join(tempDir.path, 'novel_metadata.db'));

    final novelDatabase = NovelDatabase(dbDirPath: tempDir.path);
    try {
      final db = await novelDatabase.database;
      expect(await db.getVersion(), 14);

      final remote = (await db.query('sync_remote_progress')).single;
      expect(remote['novel_id'], 'narou_n1');
      expect(remote['device_name'], 'iPad');
      expect(remote['episode'], 5);
      expect(remote.containsKey('url'), isTrue);
      expect(remote['url'], isNull);
      expect(remote.containsKey('title'), isTrue);
      expect(remote['title'], isNull);

      final own = (await db.query('sync_own_progress')).single;
      expect(own['novel_id'], 'narou_n2');
      expect(own['read_at'], '2026-11-02T00:00:00.000Z');
      expect(own.containsKey('url'), isTrue);
      expect(own['url'], isNull);
      expect(own.containsKey('title'), isTrue);
      expect(own['title'], isNull);
    } finally {
      await novelDatabase.close();
    }
  });

  test('a v13 database upgraded to v14 matches fresh sync tables', () async {
    final upgradedDir = Directory(p.join(tempDir.path, 'upgraded'))
      ..createSync();
    final freshDir = Directory(p.join(tempDir.path, 'fresh'))..createSync();
    await _seedV13(p.join(upgradedDir.path, 'novel_metadata.db'));

    final upgraded = NovelDatabase(dbDirPath: upgradedDir.path);
    final fresh = NovelDatabase(dbDirPath: freshDir.path);
    try {
      for (final table in ['sync_remote_progress', 'sync_own_progress']) {
        expect(
          await _columns(await upgraded.database, table),
          await _columns(await fresh.database, table),
          reason: table,
        );
      }
    } finally {
      await upgraded.close();
      await fresh.close();
    }
  });
}
