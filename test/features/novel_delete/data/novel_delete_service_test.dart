import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/novel_delete/data/novel_delete_service.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

/// A reading-progress repository whose cascade delete always throws, used to
/// prove the novels + reading_progress deletes run in a single transaction that
/// rolls back as a unit (F127).
class _ThrowingReadingProgressRepository extends ReadingProgressRepository {
  _ThrowingReadingProgressRepository(super.novelDatabase);

  @override
  Future<void> deleteByNovelId(String novelId, {DatabaseExecutor? txn}) async {
    throw Exception('reading_progress delete failed');
  }
}

void main() {
  late NovelDatabase novelDatabase;
  late NovelRepository novelRepository;
  late ReadingProgressRepository readingProgressRepository;
  late FileSystemService fileSystemService;
  late NovelDeleteService deleteService;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    novelRepository = NovelRepository(novelDatabase);
    readingProgressRepository = ReadingProgressRepository(novelDatabase);
    fileSystemService = FileSystemService();
    deleteService = NovelDeleteService(
      novelDatabase: novelDatabase,
      novelRepository: novelRepository,
      readingProgressRepository: readingProgressRepository,
      fileSystemService: fileSystemService,
    );
    tempDir = Directory.systemTemp.createTempSync('novel_delete_test_');
  });

  tearDown(() async {
    await novelDatabase.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  NovelMetadata createMetadata({
    String folderName = 'narou_n1234ab',
    String novelId = 'n1234ab',
    String title = 'テスト小説',
  }) {
    return NovelMetadata(
      siteType: 'narou',
      novelId: novelId,
      title: title,
      url: 'https://ncode.syosetu.com/$novelId/',
      folderName: folderName,
      episodeCount: 10,
      downloadedAt: DateTime(2026, 1, 1),
    );
  }

  group('NovelDeleteService', () {
    test('deletes novel record from database', () async {
      await novelRepository.upsert(createMetadata());
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();

      await deleteService.delete('narou_n1234ab', novelDir.path);

      final novel = await novelRepository.findByFolderName('narou_n1234ab');
      expect(novel, isNull);
    });

    test('deletes directory from file system (carrying novel_data.db with it)',
        () async {
      await novelRepository.upsert(createMetadata());
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();
      File('${novelDir.path}/001_chapter.txt').writeAsStringSync('content');
      // A novel_data.db (word_summaries/fact_cache/bookmarks) would live here;
      // deleting the directory removes it — no per-row cascade is run.
      File('${novelDir.path}/novel_data.db').writeAsStringSync('x');

      await deleteService.delete('narou_n1234ab', novelDir.path);

      expect(novelDir.existsSync(), false);
    });

    test('deletes reading_progress row for the folder', () async {
      await novelRepository.upsert(createMetadata());
      await readingProgressRepository.upsert(
        novelId: 'narou_n1234ab',
        fileName: '003_chapter3.txt',
      );
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();

      await deleteService.delete('narou_n1234ab', novelDir.path);

      final progress =
          await readingProgressRepository.findByNovelId('narou_n1234ab');
      expect(progress, isNull);
    });

    test('deletes folder even when episode_cache.db is open', () async {
      // Regression: a novel downloaded then viewed leaves episode_cache.db open
      // (the download flow's handle). On Windows that open SQLite connection
      // locked the file, so deleteDirectory failed part-way. The fix releases
      // the handle before deleting and only removes DB rows after the folder is
      // gone.
      await novelRepository.upsert(createMetadata());
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();
      File('${novelDir.path}/001_chapter.txt').writeAsStringSync('content');

      final cacheDb = EpisodeCacheDatabase(novelDir.path);
      await cacheDb.database;
      expect(
        File('${novelDir.path}/episode_cache.db').existsSync(),
        isTrue,
        reason: 'episode_cache.db should exist and be open before deletion',
      );

      final serviceWithRelease = NovelDeleteService(
        novelDatabase: novelDatabase,
        novelRepository: novelRepository,
        readingProgressRepository: readingProgressRepository,
        fileSystemService: fileSystemService,
        releaseFolderHandles: (dir) async {
          await cacheDb.close();
        },
      );

      await serviceWithRelease.delete('narou_n1234ab', novelDir.path);

      expect(novelDir.existsSync(), isFalse,
          reason: 'the folder SHALL be deleted once the handle is released');
      expect(
        await novelRepository.findByFolderName('narou_n1234ab'),
        isNull,
      );
    });

    test('DB row deletion is atomic — a mid-transaction failure rolls back '
        'novels and reading_progress (F127)', () async {
      await novelRepository.upsert(createMetadata());
      await readingProgressRepository.upsert(
        novelId: 'narou_n1234ab',
        fileName: '001.txt',
      );
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();

      final failingService = NovelDeleteService(
        novelDatabase: novelDatabase,
        novelRepository: novelRepository,
        readingProgressRepository:
            _ThrowingReadingProgressRepository(novelDatabase),
        fileSystemService: fileSystemService,
      );

      await expectLater(
        failingService.delete('narou_n1234ab', novelDir.path),
        throwsA(isA<Exception>()),
      );

      // Folder was deleted (fs deletion precedes the DB transaction), but every
      // DB row SHALL survive the rolled-back transaction.
      expect(await novelRepository.findByFolderName('narou_n1234ab'), isNotNull,
          reason: 'novels row SHALL be rolled back');
      expect(
        await readingProgressRepository.findByNovelId('narou_n1234ab'),
        isNotNull,
        reason: 'reading_progress SHALL be rolled back',
      );
    });

    test('does not affect other novels', () async {
      await novelRepository.upsert(createMetadata());
      await novelRepository.upsert(createMetadata(
        folderName: 'narou_n5678cd',
        novelId: 'n5678cd',
        title: '別の小説',
      ));
      await readingProgressRepository.upsert(
        novelId: 'narou_n5678cd',
        fileName: '002_chapter2.txt',
      );
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();

      await deleteService.delete('narou_n1234ab', novelDir.path);

      expect(
        await novelRepository.findByFolderName('narou_n5678cd'),
        isNotNull,
      );
      expect(
        await readingProgressRepository.findByNovelId('narou_n5678cd'),
        isNotNull,
        reason: 'other novel\'s reading_progress SHALL be preserved',
      );
    });
  });
}
