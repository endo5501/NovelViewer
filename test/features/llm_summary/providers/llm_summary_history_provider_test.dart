import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
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
}

ProviderContainer _containerFor({
  required LlmSummaryRepository repository,
  required FactCacheRepository factCacheRepository,
  required String? directoryPath,
}) {
  return ProviderContainer(
    overrides: [
      llmSummaryRepositoryProvider.overrideWith((ref) async => repository),
      factCacheRepositoryProvider
          .overrideWith((ref) async => factCacheRepository),
      currentDirectoryProvider
          .overrideWith(() => CurrentDirectoryNotifier(directoryPath)),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late LlmSummaryRepository repository;
  late FactCacheRepository factCacheRepository;

  setUp(() async {
    db = await _openDb();
    repository = LlmSummaryRepository(db);
    factCacheRepository = FactCacheRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insert({
    required String folder,
    required String word,
    required int episode,
    String? sourceFile,
    required String summary,
    required String updatedAt,
  }) async {
    await db.insert('word_summaries', {
      'folder_name': folder,
      'word': word,
      'covered_up_to_episode': episode,
      'summary': summary,
      'source_file': sourceFile,
      'created_at': updatedAt,
      'updated_at': updatedAt,
    });
  }

  group('llmSummaryHistoryProvider', () {
    test('returns empty list when no current directory is set', () async {
      final container =
          _containerFor(
          repository: repository,
          factCacheRepository: factCacheRepository,
          directoryPath: null);
      addTearDown(container.dispose);

      final entries =
          await container.read(llmSummaryHistoryProvider.future);
      expect(entries, isEmpty);
    });

    test('returns merged entries ordered by updated_at desc', () async {
      final older = DateTime.utc(2026, 5, 20, 10).toIso8601String();
      final middle = DateTime.utc(2026, 5, 20, 12).toIso8601String();
      final newer = DateTime.utc(2026, 5, 20, 14).toIso8601String();

      await insert(
        folder: 'my_novel',
        word: '中間',
        episode: 30,
        sourceFile: '030.txt',
        summary: 'm',
        updatedAt: middle,
      );
      await insert(
        folder: 'my_novel',
        word: '新しい',
        episode: 50,
        sourceFile: '050.txt',
        summary: 'n',
        updatedAt: newer,
      );
      await insert(
        folder: 'my_novel',
        word: '古い',
        episode: 10,
        sourceFile: '010.txt',
        summary: 'o',
        updatedAt: older,
      );
      await insert(
        folder: 'other_novel',
        word: '他',
        episode: 999,
        sourceFile: '999.txt',
        summary: 'x',
        updatedAt: newer,
      );

      final container = _containerFor(
        repository: repository,
        factCacheRepository: factCacheRepository,
        directoryPath: '/library/my_novel',
      );
      addTearDown(container.dispose);

      final entries =
          await container.read(llmSummaryHistoryProvider.future);

      expect(entries.map((e) => e.word).toList(), ['新しい', '中間', '古い']);
    });

    test('multiple snapshots of the same word collapse into one entry',
        () async {
      final t1 = DateTime.utc(2026, 5, 20, 10).toIso8601String();
      final t2 = DateTime.utc(2026, 5, 20, 16).toIso8601String();
      final t3 = DateTime.utc(2026, 5, 20, 18).toIso8601String();

      await insert(
        folder: 'my_novel',
        word: 'アリス',
        episode: 30,
        sourceFile: '030.txt',
        summary: '序盤',
        updatedAt: t1,
      );
      await insert(
        folder: 'my_novel',
        word: 'アリス',
        episode: 60,
        sourceFile: '060.txt',
        summary: '中盤',
        updatedAt: t2,
      );
      await insert(
        folder: 'my_novel',
        word: 'アリス',
        episode: 120,
        sourceFile: '120.txt',
        summary: '全話',
        updatedAt: t3,
      );

      final container = _containerFor(
        repository: repository,
        factCacheRepository: factCacheRepository,
        directoryPath: '/library/my_novel',
      );
      addTearDown(container.dispose);

      final entries =
          await container.read(llmSummaryHistoryProvider.future);

      expect(entries, hasLength(1));
      expect(entries.first.word, 'アリス');
      expect(entries.first.snapshotCount, 3);
      expect(entries.first.sourceFile, '120.txt',
          reason: 'jump target is the largest-episode non-null source_file');
      expect(entries.first.updatedAt, DateTime.utc(2026, 5, 20, 18));
    });
  });

  group('LlmSummaryHistoryNotifier.deleteEntry', () {
    test('removes every snapshot row for the word', () async {
      final now = DateTime.utc(2026, 5, 20, 10).toIso8601String();
      await insert(
        folder: 'my_novel',
        word: 'アリス',
        episode: 30,
        summary: 'a30',
        updatedAt: now,
      );
      await insert(
        folder: 'my_novel',
        word: 'アリス',
        episode: 100,
        summary: 'a100',
        updatedAt: now,
      );
      await insert(
        folder: 'my_novel',
        word: 'ボブ',
        episode: 30,
        summary: 'bob',
        updatedAt: now,
      );

      final container = _containerFor(
        repository: repository,
        factCacheRepository: factCacheRepository,
        directoryPath: '/library/my_novel',
      );
      addTearDown(container.dispose);

      await container.read(llmSummaryHistoryProvider.future);

      await container
          .read(llmSummaryHistoryProvider.notifier)
          .deleteEntry('アリス');

      final remaining = await repository.findAllByFolder('my_novel');
      expect(remaining.map((r) => r.word).toSet(), {'ボブ'});
    });

    test('cascades deletion to the fact cache', () async {
      final now = DateTime.utc(2026, 5, 20, 10).toIso8601String();
      await insert(
        folder: 'my_novel',
        word: 'アリス',
        episode: 30,
        summary: 'a30',
        updatedAt: now,
      );
      await factCacheRepository.upsert(
        folderName: 'my_novel',
        word: 'アリス',
        fileName: '030.txt',
        facts: '- 事実',
        contentHash: 'h1',
        promptVersion: FactCacheRepository.currentPromptVersion,
      );
      await factCacheRepository.upsert(
        folderName: 'my_novel',
        word: 'ボブ',
        fileName: '030.txt',
        facts: '- 別事実',
        contentHash: 'h2',
        promptVersion: FactCacheRepository.currentPromptVersion,
      );

      final container = _containerFor(
        repository: repository,
        factCacheRepository: factCacheRepository,
        directoryPath: '/library/my_novel',
      );
      addTearDown(container.dispose);

      await container.read(llmSummaryHistoryProvider.future);
      await container
          .read(llmSummaryHistoryProvider.notifier)
          .deleteEntry('アリス');

      expect(
        await factCacheRepository.findForWord(
            folderName: 'my_novel', word: 'アリス'),
        isEmpty,
        reason: 'deleting a word SHALL cascade to its fact_cache rows',
      );
      expect(
        await factCacheRepository.findForWord(
            folderName: 'my_novel', word: 'ボブ'),
        hasLength(1),
        reason: 'other words SHALL be preserved',
      );
    });

    test('refreshes the provider state after deletion', () async {
      final now = DateTime.utc(2026, 5, 20, 10).toIso8601String();
      await insert(
        folder: 'my_novel',
        word: 'アリス',
        episode: 30,
        summary: 'a',
        updatedAt: now,
      );

      final container = _containerFor(
        repository: repository,
        factCacheRepository: factCacheRepository,
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

    test('external invalidate re-reads new snapshots', () async {
      final container = _containerFor(
        repository: repository,
        factCacheRepository: factCacheRepository,
        directoryPath: '/library/my_novel',
      );
      addTearDown(container.dispose);

      var entries = await container.read(llmSummaryHistoryProvider.future);
      expect(entries, isEmpty);

      await repository.saveSnapshot(
        folderName: 'my_novel',
        word: '聖印',
        coveredUpToEpisode: 50,
        summary: '神聖な刻印',
        sourceFile: '050.txt',
      );

      entries = await container.read(llmSummaryHistoryProvider.future);
      expect(entries, isEmpty,
          reason: 'cached value remains until externally invalidated');

      container.invalidate(llmSummaryHistoryProvider);
      entries = await container.read(llmSummaryHistoryProvider.future);
      expect(entries, hasLength(1));
      expect(entries.first.word, '聖印');
    });

    test('no-op when no current directory is set', () async {
      final container =
          _containerFor(
          repository: repository,
          factCacheRepository: factCacheRepository,
          directoryPath: null);
      addTearDown(container.dispose);

      await container.read(llmSummaryHistoryProvider.future);

      await container
          .read(llmSummaryHistoryProvider.notifier)
          .deleteEntry('アリス');
    });
  });

  HistoryEntry entry({
    required String folder,
    required String word,
    String? sourceFile,
  }) {
    final snap = WordSummary(
      folderName: folder,
      word: word,
      coveredUpToEpisode: sourceFile == null
          ? 1
          : int.tryParse(sourceFile.split('_').first.replaceAll(
                    RegExp(r'[^0-9]'),
                    '',
                  )) ??
              1,
      summary: 'summary',
      sourceFile: sourceFile,
      createdAt: DateTime.utc(2026, 5, 21),
      updatedAt: DateTime.utc(2026, 5, 21),
    );
    return HistoryEntry.mergeRows([snap]).single;
  }

  group('LlmSummaryHistoryNotifier.openEntry', () {
    test('jumps to the first line containing the word', () async {
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
        factCacheRepository: factCacheRepository,
        directoryPath: tempDir.path,
      );
      addTearDown(container.dispose);

      await container.read(llmSummaryHistoryProvider.future);

      await container.read(llmSummaryHistoryProvider.notifier).openEntry(
            entry(
              folder: 'open_entry',
              word: 'アリス',
              sourceFile: '040_chapter.txt',
            ),
          );

      final selected = container.read(selectedFileProvider);
      expect(selected?.name, '040_chapter.txt');
      expect(p.equals(selected?.path ?? '', file.path), isTrue);
      expect(container.read(bookmarkJumpLineProvider), 2);
    });

    test('opens but skips jump when word not in file', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('open_entry_miss_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final file = File('${tempDir.path}/050_chapter.txt');
      await file.writeAsString('全く関係ない本文だけ\nが書かれている');

      final container = _containerFor(
        repository: repository,
        factCacheRepository: factCacheRepository,
        directoryPath: tempDir.path,
      );
      addTearDown(container.dispose);

      await container.read(llmSummaryHistoryProvider.future);

      await container.read(llmSummaryHistoryProvider.notifier).openEntry(
            entry(
              folder: 'open_entry_miss',
              word: 'いない単語',
              sourceFile: '050_chapter.txt',
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

    test('no-op when sourceFile is null', () async {
      final container = _containerFor(
        repository: repository,
        factCacheRepository: factCacheRepository,
        directoryPath: '/library/my_novel',
      );
      addTearDown(container.dispose);

      await container.read(llmSummaryHistoryProvider.future);

      await container.read(llmSummaryHistoryProvider.notifier).openEntry(
            entry(
              folder: 'my_novel',
              word: 'アリス',
              sourceFile: null,
            ),
          );

      expect(container.read(selectedFileProvider), isNull);
      expect(container.read(bookmarkJumpLineProvider), isNull);
    });

    test('no-op when the resolved file does not exist on disk', () async {
      final container = _containerFor(
        repository: repository,
        factCacheRepository: factCacheRepository,
        directoryPath: '/library/nonexistent',
      );
      addTearDown(container.dispose);

      await container.read(llmSummaryHistoryProvider.future);

      await container.read(llmSummaryHistoryProvider.notifier).openEntry(
            entry(
              folder: 'nonexistent',
              word: 'アリス',
              sourceFile: '040_chapter.txt',
            ),
          );

      expect(container.read(selectedFileProvider), isNull);
      expect(container.read(bookmarkJumpLineProvider), isNull);
    });
  });
}
