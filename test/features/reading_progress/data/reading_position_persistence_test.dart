import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import '../../../helpers/novel_metadata_db_fixture.dart';

void main() {
  test(
    'saved position is returned and latest lookup resolves timestamp ties',
    () async {
      final database = await seedNovelDatabaseFixture();
      addTearDown(database.close);
      final repo = ReadingProgressRepository(database);
      await repo.upsert(novelId: 'b', fileName: 'one.txt');
      await repo.savePosition(
        novelId: 'b',
        fileName: 'one.txt',
        bodyOffset: 25,
        bodyHash: 'hash',
      );
      final saved = await repo.findByNovelId('b');
      expect(saved!.bodyOffset, 25);
      expect(saved.bodyHash, 'hash');
      await repo.upsert(novelId: 'a', fileName: 'two.txt');
      final db = await database.database;
      await db.update('reading_progress', {
        'updated_at': '2026-01-01T00:00:00.000',
      });
      expect((await repo.findLatest())!.novelId, 'a');
      await repo.deleteByNovelId('b');
      await repo.savePosition(
        novelId: 'b',
        fileName: 'one.txt',
        bodyOffset: 30,
        bodyHash: 'hash',
      );
      expect(await repo.findByNovelId('b'), isNull);
      await db.execute('DROP TABLE reading_progress');
      await expectLater(repo.findLatest(), throwsA(isA<Object>()));
    },
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'v9 history migrates without losing progress or changing fresh schema',
    () async {
      final dir = await Directory.systemTemp.createTemp('reading-position-');
      final old = await openDatabase(
        '${dir.path}/novel_metadata.db',
        version: 9,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE reading_progress (novel_id TEXT NOT NULL PRIMARY KEY, file_name TEXT NOT NULL, updated_at TEXT NOT NULL)',
          );
          await db.insert('reading_progress', {
            'novel_id': 'book',
            'file_name': '001.txt',
            'updated_at': '2026-01-01T00:00:00.000',
          });
        },
      );
      await old.close();
      final migrated = NovelDatabase(dbDirPath: dir.path);
      final fresh = await openInMemoryNovelMetadataDb();
      try {
        final db = await migrated.database;
        final row = (await db.query('reading_progress')).single;
        expect(row['file_name'], '001.txt');
        expect(row['body_offset'], 0);
        expect(row['body_hash'], isNull);
        expect(
          await db.rawQuery('PRAGMA table_info(reading_progress)'),
          await fresh.rawQuery('PRAGMA table_info(reading_progress)'),
        );
      } finally {
        await migrated.close();
        await fresh.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'file-only upsert preserves same-file position and resets other file',
    () async {
      final database = await seedNovelDatabaseFixture();
      addTearDown(database.close);
      final repo = ReadingProgressRepository(database);
      await repo.upsert(novelId: 'book', fileName: 'a.txt');
      final db = await database.database;
      await db.update('reading_progress', {
        'body_offset': 42,
        'body_hash': 'hash',
      });
      await repo.upsert(novelId: 'book', fileName: 'a.txt');
      expect((await db.query('reading_progress')).single['body_offset'], 42);
      await repo.upsert(novelId: 'book', fileName: 'b.txt');
      final row = (await db.query('reading_progress')).single;
      expect(row['body_offset'], 0);
      expect(row['body_hash'], isNull);
    },
  );
}
