import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
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

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        llmSummaryRepositoryProvider.overrideWith((_) async => repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('hoverPopupCacheProvider', () {
    test('returns both summaries when noSpoiler and spoiler caches exist',
        () async {
      await repository.saveSummary(
        folderName: 'novel_a',
        word: 'アリス',
        summaryType: SummaryType.noSpoiler,
        summary: 'アリスは主人公。',
        sourceFile: '040_chapter.txt',
      );
      await repository.saveSummary(
        folderName: 'novel_a',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
        summary: 'アリスは第三王女で剣術の達人。',
      );

      final container = makeContainer();
      final result = await container.read(
        hoverPopupCacheProvider(
          const HoverPopupCacheKey(folder: 'novel_a', word: 'アリス'),
        ).future,
      );

      expect(result.noSpoiler, isNotNull);
      expect(result.noSpoiler!.summary, 'アリスは主人公。');
      expect(result.noSpoiler!.sourceFile, '040_chapter.txt');
      expect(result.spoiler, isNotNull);
      expect(result.spoiler!.summary, 'アリスは第三王女で剣術の達人。');
    });

    test('returns only noSpoiler when only no-spoiler cache exists', () async {
      await repository.saveSummary(
        folderName: 'novel_a',
        word: 'ボブ',
        summaryType: SummaryType.noSpoiler,
        summary: 'ボブは友人。',
      );

      final container = makeContainer();
      final result = await container.read(
        hoverPopupCacheProvider(
          const HoverPopupCacheKey(folder: 'novel_a', word: 'ボブ'),
        ).future,
      );

      expect(result.noSpoiler, isNotNull);
      expect(result.noSpoiler!.summary, 'ボブは友人。');
      expect(result.spoiler, isNull);
    });

    test('returns only spoiler when only spoiler cache exists', () async {
      await repository.saveSummary(
        folderName: 'novel_a',
        word: '聖印',
        summaryType: SummaryType.spoiler,
        summary: '聖印は神聖な印章。',
      );

      final container = makeContainer();
      final result = await container.read(
        hoverPopupCacheProvider(
          const HoverPopupCacheKey(folder: 'novel_a', word: '聖印'),
        ).future,
      );

      expect(result.noSpoiler, isNull);
      expect(result.spoiler, isNotNull);
      expect(result.spoiler!.summary, '聖印は神聖な印章。');
    });

    test('returns both null when no cache exists for the word', () async {
      final container = makeContainer();
      final result = await container.read(
        hoverPopupCacheProvider(
          const HoverPopupCacheKey(folder: 'novel_a', word: 'メアリ'),
        ).future,
      );

      expect(result.noSpoiler, isNull);
      expect(result.spoiler, isNull);
    });

    test('scopes lookup by folder (does not bleed across folders)', () async {
      await repository.saveSummary(
        folderName: 'novel_a',
        word: 'アリス',
        summaryType: SummaryType.noSpoiler,
        summary: 'アリス (novel_a)',
      );

      final container = makeContainer();
      final result = await container.read(
        hoverPopupCacheProvider(
          const HoverPopupCacheKey(folder: 'novel_b', word: 'アリス'),
        ).future,
      );

      expect(result.noSpoiler, isNull,
          reason: 'A summary in novel_a must not appear when querying novel_b');
      expect(result.spoiler, isNull);
    });

    test('HoverPopupCacheKey equal keys produce identical provider entries',
        () {
      final container = makeContainer();
      final a = container.read(hoverPopupCacheProvider(
              const HoverPopupCacheKey(folder: 'novel_a', word: 'アリス'))
          .future);
      final b = container.read(hoverPopupCacheProvider(
              const HoverPopupCacheKey(folder: 'novel_a', word: 'アリス'))
          .future);

      expect(identical(a, b), isTrue,
          reason:
              'Family providers must reuse the same Future for equal keys');
    });
  });
}
