import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> _openDb() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
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
}

ProviderContainer _containerFor({
  required LlmSummaryRepository repository,
  required String? directoryPath,
}) {
  return ProviderContainer(
    overrides: [
      llmSummaryRepositoryProvider.overrideWith((ref) async => repository),
      currentDirectoryProvider
          .overrideWith(() => CurrentDirectoryNotifier(directoryPath)),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late LlmSummaryRepository repository;

  setUp(() async {
    db = await _openDb();
    repository = LlmSummaryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('llmSummaryHistoryProvider', () {
    test('returns empty list when no current directory is set', () async {
      final container =
          _containerFor(repository: repository, directoryPath: null);
      addTearDown(container.dispose);

      final entries =
          await container.read(llmSummaryHistoryProvider.future);
      expect(entries, isEmpty);
    });

    test('returns merged entries for active folder ordered by updated_at desc',
        () async {
      // Seed 3 distinct words with controlled timestamps in folder "my_novel".
      final older = DateTime.utc(2026, 5, 20, 10).toIso8601String();
      final middle = DateTime.utc(2026, 5, 20, 12).toIso8601String();
      final newer = DateTime.utc(2026, 5, 20, 14).toIso8601String();

      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': '中間',
        'summary_type': 'spoiler',
        'summary': 'm',
        'source_file': '030.txt',
        'created_at': middle,
        'updated_at': middle,
      });
      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': '新しい',
        'summary_type': 'no_spoiler',
        'summary': 'n',
        'source_file': '050.txt',
        'created_at': newer,
        'updated_at': newer,
      });
      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': '古い',
        'summary_type': 'spoiler',
        'summary': 'o',
        'source_file': '010.txt',
        'created_at': older,
        'updated_at': older,
      });
      // Different folder — must be excluded.
      await db.insert('word_summaries', {
        'folder_name': 'other_novel',
        'word': '他',
        'summary_type': 'spoiler',
        'summary': 'x',
        'source_file': '999.txt',
        'created_at': newer,
        'updated_at': newer,
      });

      final container = _containerFor(
        repository: repository,
        directoryPath: '/library/my_novel',
      );
      addTearDown(container.dispose);

      final entries =
          await container.read(llmSummaryHistoryProvider.future);

      expect(entries.map((e) => e.word).toList(), ['新しい', '中間', '古い']);
    });

    test('merges no_spoiler and spoiler rows of the same word into "both"',
        () async {
      final t1 = DateTime.utc(2026, 5, 20, 10).toIso8601String();
      final t2 = DateTime.utc(2026, 5, 20, 16).toIso8601String();

      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': 'アリス',
        'summary_type': 'no_spoiler',
        'summary': 'なし要約',
        'source_file': '040.txt',
        'created_at': t1,
        'updated_at': t1,
      });
      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': 'アリス',
        'summary_type': 'spoiler',
        'summary': 'あり要約',
        'source_file': '060.txt',
        'created_at': t2,
        'updated_at': t2,
      });

      final container = _containerFor(
        repository: repository,
        directoryPath: '/library/my_novel',
      );
      addTearDown(container.dispose);

      final entries =
          await container.read(llmSummaryHistoryProvider.future);

      expect(entries, hasLength(1));
      expect(entries.first.word, 'アリス');
      expect(entries.first.type, HistoryEntryType.both);
      expect(entries.first.sourceFile, '040.txt');
    });
  });

  group('LlmSummaryHistoryNotifier.deleteEntry', () {
    test('removes both no_spoiler and spoiler rows for the word', () async {
      final now = DateTime.utc(2026, 5, 20, 10).toIso8601String();
      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': 'アリス',
        'summary_type': 'no_spoiler',
        'summary': 'なし要約',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': 'アリス',
        'summary_type': 'spoiler',
        'summary': 'あり要約',
        'created_at': now,
        'updated_at': now,
      });
      // A different word that must NOT be touched.
      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': 'ボブ',
        'summary_type': 'spoiler',
        'summary': 'ボブの要約',
        'created_at': now,
        'updated_at': now,
      });

      final container = _containerFor(
        repository: repository,
        directoryPath: '/library/my_novel',
      );
      addTearDown(container.dispose);

      // Prime the provider so it's listening.
      await container.read(llmSummaryHistoryProvider.future);

      await container
          .read(llmSummaryHistoryProvider.notifier)
          .deleteEntry('アリス');

      // Reading raw repository: アリスは消え、ボブは残る
      final remaining = await repository.findAllByFolder('my_novel');
      expect(remaining.map((r) => r.word).toSet(), {'ボブ'});
    });

    test('refreshes the provider state after deletion', () async {
      final now = DateTime.utc(2026, 5, 20, 10).toIso8601String();
      await db.insert('word_summaries', {
        'folder_name': 'my_novel',
        'word': 'アリス',
        'summary_type': 'spoiler',
        'summary': 'a',
        'created_at': now,
        'updated_at': now,
      });

      final container = _containerFor(
        repository: repository,
        directoryPath: '/library/my_novel',
      );
      addTearDown(container.dispose);

      final initial = await container.read(llmSummaryHistoryProvider.future);
      expect(initial, hasLength(1));

      await container
          .read(llmSummaryHistoryProvider.notifier)
          .deleteEntry('アリス');

      final refreshed =
          await container.read(llmSummaryHistoryProvider.future);
      expect(refreshed, isEmpty);
    });

    test(
        'external invalidate of the provider causes a re-read so newly '
        'saved rows become visible', () async {
      final container = _containerFor(
        repository: repository,
        directoryPath: '/library/my_novel',
      );
      addTearDown(container.dispose);

      // Initial state: empty
      var entries = await container.read(llmSummaryHistoryProvider.future);
      expect(entries, isEmpty);

      // External code saves a row via the repository directly.
      await repository.saveSummary(
        folderName: 'my_novel',
        word: '聖印',
        summaryType: SummaryType.spoiler,
        summary: '神聖な刻印',
        sourceFile: '050.txt',
      );

      // Without invalidation the cached AsyncValue is still empty.
      entries = await container.read(llmSummaryHistoryProvider.future);
      expect(entries, isEmpty,
          reason:
              'provider returns cached value until externally invalidated');

      // Invalidating forces a re-read.
      container.invalidate(llmSummaryHistoryProvider);
      entries = await container.read(llmSummaryHistoryProvider.future);
      expect(entries, hasLength(1));
      expect(entries.first.word, '聖印');
    });

    test('no-op when no current directory is set', () async {
      final container =
          _containerFor(repository: repository, directoryPath: null);
      addTearDown(container.dispose);

      await container.read(llmSummaryHistoryProvider.future);

      // Should not throw.
      await container
          .read(llmSummaryHistoryProvider.notifier)
          .deleteEntry('アリス');
    });
  });

  group('LlmSummaryHistoryNotifier.openEntry', () {
    test(
        'sets selectedFile to the resolved sourceFile and jumps to the first '
        'line containing the word', () async {
      final tempDir = await Directory.systemTemp.createTemp('open_entry_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final file = File('${tempDir.path}/040_chapter.txt');
      await file.writeAsString('line1\nアリスが登場した。\nline3');

      final container = _containerFor(
        repository: repository,
        directoryPath: tempDir.path,
      );
      addTearDown(container.dispose);

      await container.read(llmSummaryHistoryProvider.future);

      await container.read(llmSummaryHistoryProvider.notifier).openEntry(
            HistoryEntry(
              folderName: 'open_entry',
              word: 'アリス',
              type: HistoryEntryType.spoilerOnly,
              summaryPreview: 'アリスは主人公',
              sourceFile: '040_chapter.txt',
              updatedAt: DateTime.utc(2026, 5, 21),
            ),
          );

      final selected = container.read(selectedFileProvider);
      expect(selected?.name, '040_chapter.txt');
      expect(p.equals(selected?.path ?? '', file.path), isTrue);
      expect(container.read(bookmarkJumpLineProvider), 2);
    });

    test('opens the file but skips the jump when the word is not in the file',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('open_entry_miss_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final file = File('${tempDir.path}/050_chapter.txt');
      await file.writeAsString('全く関係ない本文だけ\nが書かれている');

      final container = _containerFor(
        repository: repository,
        directoryPath: tempDir.path,
      );
      addTearDown(container.dispose);

      await container.read(llmSummaryHistoryProvider.future);

      await container.read(llmSummaryHistoryProvider.notifier).openEntry(
            HistoryEntry(
              folderName: 'open_entry_miss',
              word: 'いない単語',
              type: HistoryEntryType.spoilerOnly,
              summaryPreview: '存在しない',
              sourceFile: '050_chapter.txt',
              updatedAt: DateTime.utc(2026, 5, 21),
            ),
          );

      expect(
        p.equals(
          container.read(selectedFileProvider)?.path ?? '',
          file.path,
        ),
        isTrue,
      );
      expect(container.read(bookmarkJumpLineProvider), isNull);
    });

    test('no-op when entry has null sourceFile', () async {
      final container = _containerFor(
        repository: repository,
        directoryPath: '/library/my_novel',
      );
      addTearDown(container.dispose);

      await container.read(llmSummaryHistoryProvider.future);

      await container.read(llmSummaryHistoryProvider.notifier).openEntry(
            HistoryEntry(
              folderName: 'my_novel',
              word: 'アリス',
              type: HistoryEntryType.spoilerOnly,
              summaryPreview: 'a',
              sourceFile: null,
              updatedAt: DateTime.utc(2026, 5, 21),
            ),
          );

      expect(container.read(selectedFileProvider), isNull);
      expect(container.read(bookmarkJumpLineProvider), isNull);
    });

    test(
        'no-op when the resolved file does not exist on disk (e.g. moved or '
        'deleted)', () async {
      final container = _containerFor(
        repository: repository,
        directoryPath: '/library/nonexistent',
      );
      addTearDown(container.dispose);

      await container.read(llmSummaryHistoryProvider.future);

      await container.read(llmSummaryHistoryProvider.notifier).openEntry(
            HistoryEntry(
              folderName: 'nonexistent',
              word: 'アリス',
              type: HistoryEntryType.spoilerOnly,
              summaryPreview: 'a',
              sourceFile: '040_chapter.txt',
              updatedAt: DateTime.utc(2026, 5, 21),
            ),
          );

      expect(container.read(selectedFileProvider), isNull);
      expect(container.read(bookmarkJumpLineProvider), isNull);
    });
  });
}
