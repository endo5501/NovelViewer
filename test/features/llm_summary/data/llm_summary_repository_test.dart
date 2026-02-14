import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late LlmSummaryRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
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
    repository = LlmSummaryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LlmSummaryRepository', () {
    test('saveSummary inserts and findSummary retrieves it', () async {
      await repository.saveSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
        summary: 'アリスは主人公の少女。',
      );

      final result = await repository.findSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
      );

      expect(result, isNotNull);
      expect(result!.word, 'アリス');
      expect(result.summary, 'アリスは主人公の少女。');
      expect(result.summaryType, SummaryType.spoiler);
      expect(result.folderName, 'my_novel');
    });

    test('findSummary returns null for cache miss', () async {
      final result = await repository.findSummary(
        folderName: 'my_novel',
        word: '存在しない単語',
        summaryType: SummaryType.spoiler,
      );

      expect(result, isNull);
    });

    test('saveSummary updates existing entry on conflict', () async {
      await repository.saveSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
        summary: '初回の要約',
      );

      await repository.saveSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
        summary: '更新された要約',
      );

      final result = await repository.findSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
      );

      expect(result!.summary, '更新された要約');
    });

    test('spoiler and noSpoiler are cached independently', () async {
      await repository.saveSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
        summary: 'ネタバレあり要約',
      );

      await repository.saveSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.noSpoiler,
        summary: 'ネタバレなし要約',
        sourceFile: '040_chapter.txt',
      );

      final spoiler = await repository.findSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
      );
      final noSpoiler = await repository.findSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.noSpoiler,
      );

      expect(spoiler!.summary, 'ネタバレあり要約');
      expect(noSpoiler!.summary, 'ネタバレなし要約');
      expect(noSpoiler.sourceFile, '040_chapter.txt');
    });

    test('saveSummary with sourceFile for no-spoiler', () async {
      await repository.saveSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.noSpoiler,
        summary: '要約テキスト',
        sourceFile: '040_chapter.txt',
      );

      final result = await repository.findSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.noSpoiler,
      );

      expect(result!.sourceFile, '040_chapter.txt');
    });

    test('deleteSummary removes existing entry', () async {
      await repository.saveSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
        summary: '要約',
      );

      await repository.deleteSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
      );

      final result = await repository.findSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
      );

      expect(result, isNull);
    });
  });
}
