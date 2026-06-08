import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/novel_delete/data/novel_delete_service.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/episode_cache/data/episode_cache_database.dart';

void main() {
  late NovelDatabase novelDatabase;
  late Database db;
  late NovelRepository novelRepository;
  late LlmSummaryRepository summaryRepository;
  late FactCacheRepository factCacheRepository;
  late ReadingProgressRepository readingProgressRepository;
  late FileSystemService fileSystemService;
  late NovelDeleteService deleteService;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = NovelDatabase();
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE novels (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              site_type TEXT NOT NULL,
              novel_id TEXT NOT NULL,
              title TEXT NOT NULL,
              url TEXT NOT NULL,
              folder_name TEXT NOT NULL UNIQUE,
              episode_count INTEGER NOT NULL DEFAULT 0,
              downloaded_at TEXT NOT NULL,
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_novels_site_novel
            ON novels(site_type, novel_id)
          ''');
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
            CREATE UNIQUE INDEX idx_word_summaries_unique
            ON word_summaries(folder_name, word, covered_up_to_episode)
          ''');
          await db.execute('''
            CREATE TABLE reading_progress (
              novel_id TEXT NOT NULL PRIMARY KEY,
              file_path TEXT NOT NULL,
              file_name TEXT NOT NULL,
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
            CREATE UNIQUE INDEX idx_fact_cache_unique
            ON fact_cache(folder_name, word, file_name)
          ''');
        },
      ),
    );
    novelDatabase.setDatabase(db);
    novelRepository = NovelRepository(novelDatabase);
    summaryRepository = LlmSummaryRepository(db);
    factCacheRepository = FactCacheRepository(db);
    readingProgressRepository = ReadingProgressRepository(novelDatabase);
    fileSystemService = FileSystemService();
    deleteService = NovelDeleteService(
      novelRepository: novelRepository,
      summaryRepository: summaryRepository,
      factCacheRepository: factCacheRepository,
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

    test('deletes word summaries for the folder', () async {
      await novelRepository.upsert(createMetadata());
      await summaryRepository.saveSnapshot(
        folderName: 'narou_n1234ab',
        word: 'アリス',
        coveredUpToEpisode: 10,
        summary: '要約',
      );
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();

      await deleteService.delete('narou_n1234ab', novelDir.path);

      final snapshots = await summaryRepository.findSnapshotsForWord(
        folderName: 'narou_n1234ab',
        word: 'アリス',
      );
      expect(snapshots, isEmpty);
    });

    test('deletes fact_cache rows for the folder', () async {
      await novelRepository.upsert(createMetadata());
      await factCacheRepository.upsert(
        folderName: 'narou_n1234ab',
        word: 'アリス',
        fileName: '001_chapter.txt',
        facts: '- 事実',
        contentHash: 'h1',
        promptVersion: FactCacheRepository.currentPromptVersion,
      );
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();

      await deleteService.delete('narou_n1234ab', novelDir.path);

      final cached = await factCacheRepository.findForWord(
        folderName: 'narou_n1234ab',
        word: 'アリス',
      );
      expect(cached, isEmpty,
          reason: 'folder deletion SHALL cascade to fact_cache');
    });

    test('deletes directory from file system', () async {
      await novelRepository.upsert(createMetadata());
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();
      File('${novelDir.path}/001_chapter.txt').writeAsStringSync('content');

      await deleteService.delete('narou_n1234ab', novelDir.path);

      expect(novelDir.existsSync(), false);
    });

    test('deletes reading_progress row for the folder', () async {
      await novelRepository.upsert(createMetadata());
      await readingProgressRepository.upsert(
        novelId: 'narou_n1234ab',
        filePath: '/library/narou_n1234ab/003_chapter3.txt',
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
      // locked the file, so deleteDirectory failed part-way and — because the
      // metadata was deleted first — the folder became an undeletable
      // "organizational" folder. The fix releases the handle before deleting
      // and only removes DB rows after the folder is gone.
      await novelRepository.upsert(createMetadata());
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();
      File('${novelDir.path}/001_chapter.txt').writeAsStringSync('content');

      // Simulate the leaked download handle: open and keep open.
      final cacheDb = EpisodeCacheDatabase(novelDir.path);
      await cacheDb.database;
      expect(
        File('${novelDir.path}/episode_cache.db').existsSync(),
        isTrue,
        reason: 'episode_cache.db should exist and be open before deletion',
      );

      final serviceWithRelease = NovelDeleteService(
        novelRepository: novelRepository,
        summaryRepository: summaryRepository,
        factCacheRepository: factCacheRepository,
        readingProgressRepository: readingProgressRepository,
        fileSystemService: fileSystemService,
        releaseFolderHandles: (dir) async {
          // The provider wires this to close + invalidate the family handles;
          // here we close the open cache DB to mirror that contract.
          await cacheDb.close();
        },
      );

      await serviceWithRelease.delete('narou_n1234ab', novelDir.path);

      expect(novelDir.existsSync(), isFalse,
          reason: 'the folder (including episode_cache.db) SHALL be deleted '
              'once the handle is released');
      expect(
        await novelRepository.findByFolderName('narou_n1234ab'),
        isNull,
      );
    });

    test('does not affect other novels', () async {
      await novelRepository.upsert(createMetadata());
      await novelRepository.upsert(createMetadata(
        folderName: 'narou_n5678cd',
        novelId: 'n5678cd',
        title: '別の小説',
      ));
      await summaryRepository.saveSnapshot(
        folderName: 'narou_n5678cd',
        word: 'ボブ',
        coveredUpToEpisode: 10,
        summary: '別の要約',
      );
      await factCacheRepository.upsert(
        folderName: 'narou_n5678cd',
        word: 'ボブ',
        fileName: '001.txt',
        facts: '- 事実',
        contentHash: 'h2',
        promptVersion: FactCacheRepository.currentPromptVersion,
      );
      await readingProgressRepository.upsert(
        novelId: 'narou_n5678cd',
        filePath: '/library/narou_n5678cd/002_chapter2.txt',
        fileName: '002_chapter2.txt',
      );
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();

      await deleteService.delete('narou_n1234ab', novelDir.path);

      final otherNovel =
          await novelRepository.findByFolderName('narou_n5678cd');
      expect(otherNovel, isNotNull);
      final otherSnapshots = await summaryRepository.findSnapshotsForWord(
        folderName: 'narou_n5678cd',
        word: 'ボブ',
      );
      expect(otherSnapshots, isNotEmpty);
      final otherCache = await factCacheRepository.findForWord(
        folderName: 'narou_n5678cd',
        word: 'ボブ',
      );
      expect(otherCache, isNotEmpty,
          reason: 'other novel\'s fact_cache SHALL be preserved');
      final otherProgress =
          await readingProgressRepository.findByNovelId('narou_n5678cd');
      expect(otherProgress, isNotNull,
          reason: 'other novel\'s reading_progress SHALL be preserved');
    });
  });
}
