import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_service.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockLlmClient implements LlmClient {
  final String response;
  String? lastPrompt;

  _MockLlmClient(this.response);

  @override
  Future<String> generate(String prompt) async {
    lastPrompt = prompt;
    return response;
  }
}

void main() {
  late Database db;
  late LlmSummaryRepository repository;
  late TextSearchService searchService;
  late Directory tempDir;

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
    searchService = TextSearchService();
    tempDir = await Directory.systemTemp.createTemp('llm_service_test_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> createFile(String name, String content) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsString(content);
  }

  group('LlmSummaryService', () {
    test('generates spoiler summary using all files', () async {
      await createFile('001_chapter.txt', 'アリスが登場した。');
      await createFile('050_chapter.txt', 'アリスが旅に出た。');
      await createFile('100_chapter.txt', 'アリスが帰還した。');

      final mockClient = _MockLlmClient(
        jsonEncode({'summary': 'アリスは冒険者。'}),
      );

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        searchService: searchService,
      );

      final result = await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'test_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
      );

      expect(result, 'アリスは冒険者。');
      // All files should be included in prompt
      expect(mockClient.lastPrompt, contains('アリスが登場した'));
      expect(mockClient.lastPrompt, contains('アリスが旅に出た'));
      expect(mockClient.lastPrompt, contains('アリスが帰還した'));
    });

    test('generates no-spoiler summary filtering by current file', () async {
      await createFile('001_chapter.txt', 'アリスが登場した。');
      await createFile('040_chapter.txt', 'アリスが旅に出た。');
      await createFile('100_chapter.txt', 'アリスが帰還した。');

      final mockClient = _MockLlmClient(
        jsonEncode({'summary': 'アリスは旅立った少女。'}),
      );

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        searchService: searchService,
      );

      final result = await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'test_novel',
        word: 'アリス',
        summaryType: SummaryType.noSpoiler,
        currentFileName: '040_chapter.txt',
      );

      expect(result, 'アリスは旅立った少女。');
      // Only files up to 040 should be included
      expect(mockClient.lastPrompt, contains('アリスが登場した'));
      expect(mockClient.lastPrompt, contains('アリスが旅に出た'));
      expect(mockClient.lastPrompt, isNot(contains('アリスが帰還した')));
    });

    test('parses JSON response correctly', () async {
      await createFile('001.txt', 'テスト単語が出現');

      final mockClient = _MockLlmClient(
        '{"summary": "テスト単語の説明。"}',
      );

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        searchService: searchService,
      );

      final result = await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'test',
        word: 'テスト単語',
        summaryType: SummaryType.spoiler,
      );

      expect(result, 'テスト単語の説明。');
    });

    test('falls back to raw text for non-JSON response', () async {
      await createFile('001.txt', 'テスト単語が出現');

      final mockClient = _MockLlmClient(
        'これはプレーンテキストの回答です。',
      );

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        searchService: searchService,
      );

      final result = await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'test',
        word: 'テスト単語',
        summaryType: SummaryType.spoiler,
      );

      expect(result, 'これはプレーンテキストの回答です。');
    });

    test('saves result to cache', () async {
      await createFile('001.txt', 'アリスが登場');

      final mockClient = _MockLlmClient(
        jsonEncode({'summary': 'キャッシュされる要約'}),
      );

      final service = LlmSummaryService(
        llmClient: mockClient,
        repository: repository,
        searchService: searchService,
      );

      await service.generateSummary(
        directoryPath: tempDir.path,
        folderName: 'test_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
      );

      final cached = await repository.findSummary(
        folderName: 'test_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
      );

      expect(cached, isNotNull);
      expect(cached!.summary, 'キャッシュされる要約');
    });
  });
}
