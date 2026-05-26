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

class _RecordingRepository implements ReadingProgressRepository {
  final List<String> upsertCalls = [];
  ReadingProgress? Function(String) lookup;

  _RecordingRepository({this.lookup = _alwaysNull});

  static ReadingProgress? _alwaysNull(String _) => null;

  @override
  Future<void> upsert({
    required String novelId,
    required String filePath,
    required String fileName,
  }) async {
    upsertCalls.add('$novelId|$filePath');
  }

  @override
  Future<ReadingProgress?> findByNovelId(String novelId) async {
    return lookup(novelId);
  }

  @override
  Future<void> deleteByNovelId(String novelId) async {}
}

void main() {
  late NovelDatabase novelDatabase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = NovelDatabase();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE novels (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              site_type TEXT NOT NULL,
              novel_id TEXT NOT NULL,
              title TEXT NOT NULL,
              url TEXT NOT NULL,
              folder_name TEXT NOT NULL UNIQUE,
              episode_count INTEGER NOT NULL DEFAULT 0,
              downloaded_at TEXT NOT NULL,
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE reading_progress (
              novel_id TEXT NOT NULL PRIMARY KEY,
              file_path TEXT NOT NULL,
              file_name TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    novelDatabase.setDatabase(db);
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
      await tester.pumpWidget(app);

      // Resolve the ProviderScope's container so we can poke at state from
      // outside the widget tree.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NovelViewerApp)),
      );

      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(
              name: '003_chapter3.txt',
              path: '/library/narou_n1234ab/003_chapter3.txt',
            ),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(repo.upsertCalls,
          contains('narou_n1234ab|/library/narou_n1234ab/003_chapter3.txt'));
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
                filePath: chapter3.path,
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
      await tester.pumpWidget(app);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(NovelViewerApp)),
      );

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory('/library/narou_n1234ab');
      // Two pumps: one for the listener microtask scheduling, one for the
      // awaited directoryContents future and the final selectFile.
      await container.read(directoryContentsProvider.future);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      final selected = container.read(selectedFileProvider);
      expect(selected, isNotNull);
      expect(selected!.path, chapter3.path);
    },
  );
}
