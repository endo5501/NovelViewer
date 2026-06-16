import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

import '../helpers/novel_metadata_db_fixture.dart';

class _RecordingRepository implements ReadingProgressRepository {
  final List<String> upsertCalls = [];
  ReadingProgress? Function(String) lookup;

  _RecordingRepository({this.lookup = _alwaysNull});

  static ReadingProgress? _alwaysNull(String _) => null;

  @override
  Future<void> upsert({
    required String novelId,
    required String fileName,
  }) async {
    upsertCalls.add('$novelId|$fileName');
  }

  @override
  Future<ReadingProgress?> findByNovelId(String novelId) async {
    return lookup(novelId);
  }

  @override
  Future<List<ReadingProgress>> findAll() async => const [];

  @override
  Future<void> deleteByNovelId(String novelId, {DatabaseExecutor? txn}) async {}
}

void main() {
  late NovelDatabase novelDatabase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    final db = await novelDatabase.database;

    // Register the novel folder so the shared nesting-aware resolveNovelId
    // (which keys off the registered folder_name) can resolve it.
    await db.insert('novels', {
      'site_type': 'narou',
      'novel_id': 'n1234ab',
      'title': 'テスト小説',
      'url': 'https://ncode.syosetu.com/n1234ab/',
      'folder_name': 'narou_n1234ab',
      'episode_count': 10,
      'downloaded_at': DateTime(2026, 1, 1).toIso8601String(),
    });
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  Future<Widget> buildApp({
    required ReadingProgressRepository repository,
    required String initialDirectory,
    Map<String, DirectoryContents> contentsByPath = const {},
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider.overrideWithValue('/library'),
        currentDirectoryProvider
            .overrideWith(() => CurrentDirectoryNotifier(initialDirectory)),
        novelDatabaseProvider.overrideWithValue(novelDatabase),
        readingProgressRepositoryProvider.overrideWithValue(repository),
        directoryContentsProvider.overrideWith((ref) async {
          final dir = ref.watch(currentDirectoryProvider);
          if (dir == null) return DirectoryContents.empty();
          return contentsByPath[dir] ?? DirectoryContents.empty();
        }),
      ],
      child: const NovelViewerApp(),
    );
  }

  testWidgets(
    'auto-save listener is wired at startup and fires on file selection',
    (tester) async {
      final repo = _RecordingRepository();
      final app = await buildApp(
        repository: repo,
        initialDirectory: '/library/narou_n1234ab',
      );
      // `runAsync` lets sqflite_ffi's real-timer transactions inside
      // HomeScreen's bookmark providers settle. Without it the FakeAsync
      // zone reports a pending timer and fails the test before our wiring
      // assertion runs.
      await tester.runAsync(() async {
        await tester.pumpWidget(app);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(NovelViewerApp)),
        );

        container.read(selectedFileProvider.notifier).selectFile(
              const FileEntry(
                name: '003_chapter3.txt',
                path: '/library/narou_n1234ab/003_chapter3.txt',
              ),
            );
        // Yield enough microtasks for the listener's async upsert.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          repo.upsertCalls,
          contains('narou_n1234ab|003_chapter3.txt'),
        );
      });
    },
  );

  testWidgets(
    'auto-open listener is wired at startup and selects stored file on novel-folder entry',
    (tester) async {
      const chapter3 = FileEntry(
        name: '003_chapter3.txt',
        path: '/library/narou_n1234ab/003_chapter3.txt',
      );
      final repo = _RecordingRepository(
        lookup: (id) => id == 'narou_n1234ab'
            ? ReadingProgress(
                novelId: id,
                fileName: chapter3.name,
                updatedAt: DateTime(2026, 5, 26),
              )
            : null,
      );
      final app = await buildApp(
        repository: repo,
        initialDirectory: '/library',
        contentsByPath: {
          '/library/narou_n1234ab': const DirectoryContents(
            files: [chapter3],
            subdirectories: [],
          ),
        },
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(app);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(NovelViewerApp)),
        );

        container
            .read(currentDirectoryProvider.notifier)
            .setDirectory('/library/narou_n1234ab');
        await container.read(directoryContentsProvider.future);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final selected = container.read(selectedFileProvider);
        expect(selected, isNotNull);
        expect(selected!.path, chapter3.path);
      });
    },
  );
}
