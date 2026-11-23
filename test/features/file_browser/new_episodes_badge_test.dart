import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/domain/reading_progress_badge.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/localized_material_app.dart';
import '../../helpers/novel_metadata_db_fixture.dart';

NovelMetadata _novel(String folderName, {int episodeCount = 120}) {
  return NovelMetadata(
    siteType: 'narou',
    novelId: folderName.replaceFirst('narou_', ''),
    title: 'title-$folderName',
    url: 'https://ncode.syosetu.com/${folderName.replaceFirst('narou_', '')}/',
    folderName: folderName,
    episodeCount: episodeCount,
    downloadedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('ReadingProgressBadge.from', () {
    ReadingProgressBadge badge(int? latest) => ReadingProgressBadge.from(
      episodeCount: 120,
      fileName: '003_c.txt',
      latestEpisodeCount: latest,
    );

    test('a larger observed total means new episodes', () {
      expect(badge(125).hasNewEpisodes, isTrue);
    });

    test('the same total does not', () {
      expect(badge(120).hasNewEpisodes, isFalse);
    });

    test('a smaller total (episodes removed) does not', () {
      expect(badge(100).hasNewEpisodes, isFalse);
    });

    test('a novel never checked does not', () {
      expect(badge(null).hasNewEpisodes, isFalse);
    });

    test('progress is unchanged by the mark', () {
      expect(badge(125).read, 3);
      expect(badge(125).total, 120);
    });
  });

  group('readingProgressBadgesProvider', () {
    late NovelDatabase novelDatabase;
    late NovelRepository repository;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      novelDatabase = await seedNovelDatabaseFixture();
      repository = NovelRepository(novelDatabase);
    });

    tearDown(() async {
      await novelDatabase.close();
    });

    ProviderContainer makeContainer() {
      final c = ProviderContainer(
        overrides: [novelDatabaseProvider.overrideWithValue(novelDatabase)],
      );
      addTearDown(c.dispose);
      // Keep the badges alive so a reload is what the test observes.
      c.listen(readingProgressBadgesProvider, (_, _) {});
      return c;
    }

    test('follows a recorded check and a catching-up download', () async {
      await repository.upsert(_novel('narou_n1111aa'));
      final c = makeContainer();
      Future<bool> hasNew() async => (await c.read(
        readingProgressBadgesProvider.future,
      ))['narou_n1111aa']!.hasNewEpisodes;

      expect(await hasNew(), isFalse);

      await repository.recordUpdateCheck(
        'narou_n1111aa',
        latestEpisodeCount: 125,
        checkedAt: DateTime.utc(2026, 11, 23),
      );
      c.invalidate(allNovelsProvider);
      expect(await hasNew(), isTrue);

      await repository.upsert(_novel('narou_n1111aa', episodeCount: 125));
      c.invalidate(allNovelsProvider);
      expect(await hasNew(), isFalse);
    });
  });

  group('the folder tile', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<DirectoryEntry> dirs,
      required Map<String, ReadingProgressBadge> badges,
      required List<NovelMetadata> novels,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith(
              (ref) async => DirectoryContents(files: [], subdirectories: dirs),
            ),
            currentDirectoryProvider.overrideWith(
              () => CurrentDirectoryNotifier('/library'),
            ),
            libraryPathProvider.overrideWithValue('/library'),
            allNovelsProvider.overrideWith((ref) => novels),
            readingProgressBadgesProvider.overrideWith((ref) async => badges),
          ],
          child: const LocalizedMaterialApp(
            home: Scaffold(body: FileBrowserPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const novelDir = DirectoryEntry(
      name: 'narou_n1111aa',
      path: '/library/narou_n1111aa',
      displayName: 'テスト小説',
    );

    testWidgets('marks a novel with new episodes, progress intact', (
      tester,
    ) async {
      await pump(
        tester,
        dirs: [novelDir],
        novels: [_novel('narou_n1111aa')],
        badges: {
          'narou_n1111aa': const ReadingProgressBadge(
            read: 3,
            total: 120,
            hasNewEpisodes: true,
          ),
        },
      );

      expect(find.text('新着'), findsOneWidget);
      expect(find.text('3 / 120'), findsOneWidget);
    });

    testWidgets('no mark without new episodes', (tester) async {
      await pump(
        tester,
        dirs: [novelDir],
        novels: [_novel('narou_n1111aa')],
        badges: {
          'narou_n1111aa': const ReadingProgressBadge(read: 3, total: 120),
        },
      );

      expect(find.text('新着'), findsNothing);
      expect(find.text('3 / 120'), findsOneWidget);
    });

    testWidgets('an organizing folder gets no mark', (tester) async {
      await pump(
        tester,
        dirs: const [DirectoryEntry(name: '連載中', path: '/library/連載中')],
        // The novel with new episodes lives inside 連載中.
        novels: [_novel('narou_n1111aa')],
        badges: {
          'narou_n1111aa': const ReadingProgressBadge(
            read: 3,
            total: 120,
            hasNewEpisodes: true,
          ),
        },
      );

      expect(find.text('連載中'), findsOneWidget);
      expect(find.text('新着'), findsNothing);
    });
  });
}
