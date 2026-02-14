import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/novel_delete/data/novel_delete_service.dart';

void main() {
  late NovelDatabase novelDatabase;
  late Database db;
  late NovelRepository novelRepository;
  late LlmSummaryRepository summaryRepository;
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
              summary_type TEXT NOT NULL,
              summary TEXT NOT NULL,
              source_file TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_word_summaries_unique
            ON word_summaries(folder_name, word, summary_type)
          ''');
        },
      ),
    );
    novelDatabase.setDatabase(db);
    novelRepository = NovelRepository(novelDatabase);
    summaryRepository = LlmSummaryRepository(db);
    fileSystemService = FileSystemService();
    deleteService = NovelDeleteService(
      novelRepository: novelRepository,
      summaryRepository: summaryRepository,
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
      await summaryRepository.saveSummary(
        folderName: 'narou_n1234ab',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
        summary: '要約',
      );
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();

      await deleteService.delete('narou_n1234ab', novelDir.path);

      final summary = await summaryRepository.findSummary(
        folderName: 'narou_n1234ab',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
      );
      expect(summary, isNull);
    });

    test('deletes directory from file system', () async {
      await novelRepository.upsert(createMetadata());
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();
      File('${novelDir.path}/001_chapter.txt').writeAsStringSync('content');

      await deleteService.delete('narou_n1234ab', novelDir.path);

      expect(novelDir.existsSync(), false);
    });

    test('does not affect other novels', () async {
      await novelRepository.upsert(createMetadata());
      await novelRepository.upsert(createMetadata(
        folderName: 'narou_n5678cd',
        novelId: 'n5678cd',
        title: '別の小説',
      ));
      await summaryRepository.saveSummary(
        folderName: 'narou_n5678cd',
        word: 'ボブ',
        summaryType: SummaryType.spoiler,
        summary: '別の要約',
      );
      final novelDir = Directory('${tempDir.path}/narou_n1234ab');
      novelDir.createSync();

      await deleteService.delete('narou_n1234ab', novelDir.path);

      final otherNovel =
          await novelRepository.findByFolderName('narou_n5678cd');
      expect(otherNovel, isNotNull);
      final otherSummary = await summaryRepository.findSummary(
        folderName: 'narou_n5678cd',
        word: 'ボブ',
        summaryType: SummaryType.spoiler,
      );
      expect(otherSummary, isNotNull);
    });
  });
}
