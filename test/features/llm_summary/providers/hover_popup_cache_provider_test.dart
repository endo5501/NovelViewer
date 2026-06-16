import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_data_db_fixture.dart';

void main() {
  late Database db;
  late LlmSummaryRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    db = await openInMemoryNovelDataDb();
    repository = LlmSummaryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        // Folder-scoped family: any folder path resolves to the in-memory repo.
        llmSummaryRepositoryProvider.overrideWith((ref, folderPath) async {
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('hoverPopupCacheProvider', () {
    test('returns all snapshots for the word sorted by episode asc', () async {
      await repository.saveSnapshot(
        word: 'アリス',
        coveredUpToEpisode: 60,
        summary: 'mid',
        sourceFile: '060.txt',
      );
      await repository.saveSnapshot(
        word: 'アリス',
        coveredUpToEpisode: 10,
        summary: 'early',
        sourceFile: '010.txt',
      );
      await repository.saveSnapshot(
        word: 'アリス',
        coveredUpToEpisode: 120,
        summary: 'late',
        sourceFile: '120.txt',
      );

      final container = makeContainer();
      final result = await container.read(
        hoverPopupCacheProvider(
          (folderPath: '/lib/novel_a', word: 'アリス'),
        ).future,
      );

      expect(result.map((s) => s.coveredUpToEpisode).toList(), [10, 60, 120]);
    });

    test('returns empty list when no cache exists', () async {
      final container = makeContainer();
      final result = await container.read(
        hoverPopupCacheProvider(
          (folderPath: '/lib/novel_a', word: 'メアリ'),
        ).future,
      );

      expect(result, isEmpty);
    });

    test('equal keys produce identical provider entries', () {
      final container = makeContainer();
      final a = container.read(
          hoverPopupCacheProvider((folderPath: '/lib/novel_a', word: 'アリス'))
              .future);
      final b = container.read(
          hoverPopupCacheProvider((folderPath: '/lib/novel_a', word: 'アリス'))
              .future);

      expect(identical(a, b), isTrue);
    });
  });

  group('chooseDefaultSnapshot', () {
    WordSummary snap(int episode) => WordSummary(
          word: 'w',
          coveredUpToEpisode: episode,
          summary: 's$episode',
          sourceFile: '$episode.txt',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );

    test('returns null when list is empty', () {
      expect(chooseDefaultSnapshot(const [], 5), isNull);
    });

    test('picks max snapshot <= current when one exists', () {
      final result = chooseDefaultSnapshot(
        [snap(3), snap(9), snap(10), snap(20)],
        6,
      );
      expect(result?.coveredUpToEpisode, 3);
    });

    test('picks earliest snapshot when all are in the future', () {
      final result = chooseDefaultSnapshot(
        [snap(9), snap(10), snap(20)],
        6,
      );
      expect(result?.coveredUpToEpisode, 9);
    });

    test('exact-match snapshot wins', () {
      final result = chooseDefaultSnapshot(
        [snap(3), snap(6), snap(9)],
        6,
      );
      expect(result?.coveredUpToEpisode, 6);
    });

    test('single snapshot is always returned', () {
      expect(chooseDefaultSnapshot([snap(50)], 5)?.coveredUpToEpisode, 50);
      expect(chooseDefaultSnapshot([snap(2)], 5)?.coveredUpToEpisode, 2);
    });
  });
}
