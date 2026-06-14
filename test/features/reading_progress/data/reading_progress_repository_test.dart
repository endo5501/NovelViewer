import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

void main() {
  late NovelDatabase novelDatabase;
  late ReadingProgressRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    repository = ReadingProgressRepository(novelDatabase);
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  group('upsert', () {
    test('inserts a new row when none exists', () async {
      await repository.upsert(
        novelId: 'narou_n1234ab',
        fileName: '001_chapter1.txt',
      );

      final progress = await repository.findByNovelId('narou_n1234ab');
      expect(progress, isNotNull);
      expect(progress!.novelId, 'narou_n1234ab');
      expect(progress.fileName, '001_chapter1.txt');
      expect(progress.updatedAt, isNotNull);
    });

    test('replaces the existing row without creating duplicates', () async {
      await repository.upsert(
        novelId: 'narou_n1234ab',
        fileName: '001_chapter1.txt',
      );
      // Small delay so updated_at strictly moves forward.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repository.upsert(
        novelId: 'narou_n1234ab',
        fileName: '005_chapter5.txt',
      );

      final db = await novelDatabase.database;
      final rows = await db.query('reading_progress');
      expect(rows.length, 1, reason: 'novel_id PK keeps the row count at 1');

      final progress = await repository.findByNovelId('narou_n1234ab');
      expect(progress!.fileName, '005_chapter5.txt');
    });

    test('updated_at advances on upsert', () async {
      await repository.upsert(
        novelId: 'narou_n1234ab',
        fileName: '001_chapter1.txt',
      );
      final first = await repository.findByNovelId('narou_n1234ab');

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repository.upsert(
        novelId: 'narou_n1234ab',
        fileName: '005_chapter5.txt',
      );
      final second = await repository.findByNovelId('narou_n1234ab');

      expect(
        second!.updatedAt.isAfter(first!.updatedAt),
        isTrue,
      );
    });

    test('rows for different novels are independent', () async {
      await repository.upsert(
        novelId: 'narou_n1234ab',
        fileName: '001_chapter1.txt',
      );
      await repository.upsert(
        novelId: 'kakuyomu_1689',
        fileName: '002_chapter2.txt',
      );

      final a = await repository.findByNovelId('narou_n1234ab');
      final b = await repository.findByNovelId('kakuyomu_1689');
      expect(a!.fileName, '001_chapter1.txt');
      expect(b!.fileName, '002_chapter2.txt');
    });
  });

  group('findByNovelId', () {
    test('returns null when no row exists', () async {
      final progress = await repository.findByNovelId('narou_unknown');
      expect(progress, isNull);
    });

    test('returns the stored row when present', () async {
      await repository.upsert(
        novelId: 'narou_n1234ab',
        fileName: '003_chapter3.txt',
      );

      final progress = await repository.findByNovelId('narou_n1234ab');
      expect(progress, isNotNull);
      expect(progress!.fileName, '003_chapter3.txt');
    });
  });

  group('deleteByNovelId', () {
    test('removes an existing row', () async {
      await repository.upsert(
        novelId: 'narou_n1234ab',
        fileName: '001_chapter1.txt',
      );

      await repository.deleteByNovelId('narou_n1234ab');

      final progress = await repository.findByNovelId('narou_n1234ab');
      expect(progress, isNull);
    });

    test('is a no-op for a non-existent novel', () async {
      await repository.deleteByNovelId('narou_does_not_exist');
      // No exception should be thrown.
      final progress = await repository.findByNovelId('narou_does_not_exist');
      expect(progress, isNull);
    });
  });

  group('error propagation', () {
    // The repository stays a thin CRUD layer. Callers (auto-save / auto-open
    // listeners) wrap operations with try/catch and a WARNING log on
    // `Logger('reading_progress')`. The repository itself MUST raise rather
    // than silently swallow, so this contract is asserted explicitly here by
    // dropping the table and verifying the SQL error surfaces.
    Future<void> dropTable() async {
      final db = await novelDatabase.database;
      await db.execute('DROP TABLE reading_progress');
    }

    test('upsert propagates DB errors to the caller', () async {
      await dropTable();
      await expectLater(
        repository.upsert(
          novelId: 'narou_n1234ab',
          fileName: '001_chapter1.txt',
        ),
        throwsA(isA<Object>()),
      );
    });

    test('findByNovelId propagates DB errors to the caller', () async {
      await dropTable();
      await expectLater(
        repository.findByNovelId('narou_n1234ab'),
        throwsA(isA<Object>()),
      );
    });

    test('deleteByNovelId propagates DB errors to the caller', () async {
      await dropTable();
      await expectLater(
        repository.deleteByNovelId('narou_n1234ab'),
        throwsA(isA<Object>()),
      );
    });
  });
}
