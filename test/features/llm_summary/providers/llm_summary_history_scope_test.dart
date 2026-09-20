import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/shared/database/novel_data_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/db_provider_container.dart';

NovelMetadata _novel(String folderName) => NovelMetadata(
  siteType: 'narou',
  novelId: folderName,
  title: 'Title $folderName',
  url: 'https://ncode.syosetu.com/$folderName/',
  folderName: folderName,
  episodeCount: 3,
  downloadedAt: DateTime(2024, 1, 1),
);

final _novels = [_novel('narou_n1234ab'), _novel('narou_n5678cd')];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory libraryRoot;

  setUp(() async {
    libraryRoot = await Directory.systemTemp.createTemp('novel_folder_scope');
  });

  tearDown(() async {
    if (libraryRoot.existsSync()) {
      await libraryRoot.delete(recursive: true);
    }
  });

  String lib(String relative) => p.join(libraryRoot.path, relative);

  Future<Directory> makeDir(String relative) =>
      Directory(lib(relative)).create(recursive: true);

  /// Writes one `word_summaries` row into the `novel_data.db` of [folderPath],
  /// through the production schema, and closes the handle again.
  Future<void> seedSummary(String folderPath, String word) async {
    final db = await NovelDataDatabase.openFile(
      p.join(folderPath, NovelDataDatabase.databaseName),
    );
    await db.insert('word_summaries', {
      'word': word,
      'covered_up_to_episode': 1,
      'summary': 'summary of $word',
      'source_file': '001.txt',
      'created_at': '2024-01-01T00:00:00.000',
      'updated_at': '2024-01-01T00:00:00.000',
    });
    await db.close();
  }

  ProviderContainer containerAt(String directory) {
    final container = ProviderContainer(
      overrides: [
        libraryPathProvider.overrideWithValue(libraryRoot.path),
        allNovelsProvider.overrideWith((ref) async => _novels),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier(directory),
        ),
      ],
    );
    addDbContainerTearDown(container);
    return container;
  }

  bool hasNovelData(String folderPath) =>
      File(p.join(folderPath, NovelDataDatabase.databaseName)).existsSync();

  /// Reads the words held by the `novel_data.db` of [folderPath].
  Future<List<String>> summaryWords(String folderPath) async {
    final db = await NovelDataDatabase.openFile(
      p.join(folderPath, NovelDataDatabase.databaseName),
    );
    final rows = await db.query('word_summaries', columns: ['word']);
    return [for (final row in rows) row['word'] as String];
  }

  group('llmSummaryHistoryProvider の対象フォルダ', () {
    test('整理フォルダでは履歴が空で、novel_data.db も作られない', () async {
      final organizational = await makeDir('完結済み');
      final container = containerAt(organizational.path);

      final entries = await container.read(llmSummaryHistoryProvider.future);

      expect(entries, isEmpty);
      expect(hasNovelData(organizational.path), isFalse);
    });

    test('ライブラリルートでは履歴が空で、novel_data.db も作られない', () async {
      final container = containerAt(libraryRoot.path);

      final entries = await container.read(llmSummaryHistoryProvider.future);

      expect(entries, isEmpty);
      expect(hasNovelData(libraryRoot.path), isFalse);
    });

    test('登録済み小説フォルダではそのフォルダの履歴を返す', () async {
      final novelFolder = await makeDir('narou_n1234ab');
      await seedSummary(novelFolder.path, 'アリス');
      final container = containerAt(novelFolder.path);

      final entries = await container.read(llmSummaryHistoryProvider.future);

      expect(entries.map((e) => e.word), ['アリス']);
    });

    test('入れ子の小説フォルダでもその小説フォルダの履歴を返す', () async {
      final novelFolder = await makeDir(p.join('完結済み', 'narou_n5678cd'));
      await seedSummary(novelFolder.path, 'ボブ');
      final container = containerAt(novelFolder.path);

      final entries = await container.read(llmSummaryHistoryProvider.future);

      expect(entries.map((e) => e.word), ['ボブ']);
    });

    test('サブフォルダにいても、削除は小説フォルダのDBに対して行われる', () async {
      final novelFolder = await makeDir('narou_n1234ab');
      final subFolder = await makeDir(p.join('narou_n1234ab', '第二部'));
      await seedSummary(novelFolder.path, 'アリス');
      final container = containerAt(subFolder.path);

      await container.read(llmSummaryHistoryProvider.future);
      await container
          .read(llmSummaryHistoryProvider.notifier)
          .deleteEntry('アリス');

      expect(await summaryWords(novelFolder.path), isEmpty);
      expect(hasNovelData(subFolder.path), isFalse);
    });

    test('ジャンプ先は小説フォルダではなく、表示中のフォルダから組み立てる', () async {
      await makeDir('narou_n1234ab');
      final novelFolder = Directory(lib('narou_n1234ab'));
      final subFolder = await makeDir(p.join('narou_n1234ab', '第二部'));
      await seedSummary(novelFolder.path, 'アリス');
      await File(p.join(subFolder.path, '001.txt')).writeAsString('アリスが現れた\n');
      final container = containerAt(subFolder.path);

      final entries = await container.read(llmSummaryHistoryProvider.future);
      await container
          .read(llmSummaryHistoryProvider.notifier)
          .openEntry(entries.single);

      expect(
        container.read(selectedFileProvider)?.path,
        p.join(subFolder.path, '001.txt'),
      );
    });

    test('小説フォルダ内のサブフォルダでは、小説フォルダの履歴を読む', () async {
      final novelFolder = await makeDir('narou_n1234ab');
      final subFolder = await makeDir(p.join('narou_n1234ab', '第二部'));
      await seedSummary(novelFolder.path, 'アリス');
      final container = containerAt(subFolder.path);

      final entries = await container.read(llmSummaryHistoryProvider.future);

      expect(entries.map((e) => e.word), ['アリス']);
      expect(hasNovelData(subFolder.path), isFalse);
    });
  });
}
