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

    test('deleteByFolderName removes all summaries for a folder', () async {
      await repository.saveSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
        summary: '要約1',
      );
      await repository.saveSummary(
        folderName: 'my_novel',
        word: 'ボブ',
        summaryType: SummaryType.noSpoiler,
        summary: '要約2',
      );
      await repository.saveSummary(
        folderName: 'other_novel',
        word: 'キャラ',
        summaryType: SummaryType.spoiler,
        summary: '他の要約',
      );

      await repository.deleteByFolderName('my_novel');

      final alice = await repository.findSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
      );
      final bob = await repository.findSummary(
        folderName: 'my_novel',
        word: 'ボブ',
        summaryType: SummaryType.noSpoiler,
      );
      final other = await repository.findSummary(
        folderName: 'other_novel',
        word: 'キャラ',
        summaryType: SummaryType.spoiler,
      );

      expect(alice, isNull);
      expect(bob, isNull);
      expect(other, isNotNull);
    });

    test('legacy spoiler row with NULL source_file reads back as null',
        () async {
      // Simulate a legacy row written before spoiler entries persisted
      // source_file. We bypass the repository to insert NULL directly.
      final now = DateTime.now().toIso8601String();
      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': 'アリス',
        'summary_type': 'spoiler',
        'summary': '古いネタバレ要約',
        'source_file': null,
        'created_at': now,
        'updated_at': now,
      });

      final result = await repository.findSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
      );

      expect(result, isNotNull);
      expect(result!.summary, '古いネタバレ要約');
      expect(result.sourceFile, isNull,
          reason: 'legacy NULL source_file must read back as null');
    });

    test('saveSummary rejects 1-character word', () async {
      await expectLater(
        repository.saveSummary(
          folderName: 'my_novel',
          word: 'の',
          summaryType: SummaryType.spoiler,
          summary: '要約',
        ),
        throwsArgumentError,
      );

      final result = await repository.findSummary(
        folderName: 'my_novel',
        word: 'の',
        summaryType: SummaryType.spoiler,
      );
      expect(result, isNull,
          reason: 'no row should be written for 1-char word');
    });

    test('saveSummary accepts 2-character word', () async {
      await repository.saveSummary(
        folderName: 'my_novel',
        word: '聖印',
        summaryType: SummaryType.spoiler,
        summary: '騎士の証',
      );

      final result = await repository.findSummary(
        folderName: 'my_novel',
        word: '聖印',
        summaryType: SummaryType.spoiler,
      );
      expect(result, isNotNull);
      expect(result!.summary, '騎士の証');
    });

    test('findAllByFolder returns rows ordered by updated_at desc', () async {
      // Insert rows with controlled updated_at timestamps so ordering is
      // deterministic regardless of insert order.
      final older = DateTime.utc(2026, 5, 20, 10, 0, 0).toIso8601String();
      final middle = DateTime.utc(2026, 5, 20, 12, 0, 0).toIso8601String();
      final newer = DateTime.utc(2026, 5, 20, 14, 0, 0).toIso8601String();

      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': '中間',
        'summary_type': 'spoiler',
        'summary': 'm',
        'created_at': middle,
        'updated_at': middle,
      });
      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': '新しい',
        'summary_type': 'no_spoiler',
        'summary': 'n',
        'created_at': newer,
        'updated_at': newer,
      });
      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': '古い',
        'summary_type': 'spoiler',
        'summary': 'o',
        'created_at': older,
        'updated_at': older,
      });
      // Different folder should be excluded.
      await db.insert('word_summaries', {
        'folder_name': 'other_novel',
        'word': '他作品',
        'summary_type': 'spoiler',
        'summary': 'x',
        'created_at': newer,
        'updated_at': newer,
      });

      final results = await repository.findAllByFolder('my_novel');

      expect(results.map((r) => r.word).toList(), ['新しい', '中間', '古い']);
      expect(results.every((r) => r.folderName == 'my_novel'), isTrue);
    });

    test('findAllByFolder returns empty list when folder has no rows',
        () async {
      final results = await repository.findAllByFolder('empty_novel');
      expect(results, isEmpty);
    });

    test('deleteByFolderName does nothing for non-existent folder', () async {
      await repository.saveSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
        summary: '要約',
      );

      await repository.deleteByFolderName('nonexistent');

      final result = await repository.findSummary(
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
      );
      expect(result, isNotNull);
    });
  });
}
