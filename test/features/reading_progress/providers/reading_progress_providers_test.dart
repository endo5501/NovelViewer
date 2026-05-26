import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';

void main() {
  late NovelDatabase novelDatabase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = NovelDatabase();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE reading_progress (
              novel_id TEXT NOT NULL PRIMARY KEY,
              file_path TEXT NOT NULL,
              file_name TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    novelDatabase.setDatabase(db);
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  test('readingProgressRepositoryProvider resolves with novelDatabaseProvider',
      () {
    final container = ProviderContainer(
      overrides: [
        novelDatabaseProvider.overrideWithValue(novelDatabase),
      ],
    );
    addTearDown(container.dispose);

    final repository = container.read(readingProgressRepositoryProvider);
    expect(repository, isA<ReadingProgressRepository>());
  });

  test('readingProgressRepositoryProvider returns the same instance on read',
      () {
    final container = ProviderContainer(
      overrides: [
        novelDatabaseProvider.overrideWithValue(novelDatabase),
      ],
    );
    addTearDown(container.dispose);

    final a = container.read(readingProgressRepositoryProvider);
    final b = container.read(readingProgressRepositoryProvider);
    expect(identical(a, b), isTrue);
  });
}
