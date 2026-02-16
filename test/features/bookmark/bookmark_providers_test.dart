import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/bookmark/data/bookmark_repository.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';

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
        version: 3,
        onCreate: (db, version) async {
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
            CREATE TABLE bookmarks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              novel_id TEXT NOT NULL,
              file_name TEXT NOT NULL,
              file_path TEXT NOT NULL,
              created_at TEXT NOT NULL,
              UNIQUE(novel_id, file_path)
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

  ProviderContainer createContainer({
    String? libraryPath,
    String? currentDirectory,
  }) {
    return ProviderContainer(
      overrides: [
        novelDatabaseProvider.overrideWithValue(novelDatabase),
        libraryPathProvider.overrideWithValue(libraryPath ?? '/library'),
        if (currentDirectory != null)
          currentDirectoryProvider.overrideWith(
              () => CurrentDirectoryNotifier(currentDirectory)),
      ],
    );
  }

  group('currentNovelIdProvider', () {
    test('returns null when at library root', () {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library',
      );
      addTearDown(container.dispose);

      final novelId = container.read(currentNovelIdProvider);
      expect(novelId, isNull);
    });

    test('returns folder name when inside a novel directory', () {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/narou_n1234',
      );
      addTearDown(container.dispose);

      final novelId = container.read(currentNovelIdProvider);
      expect(novelId, 'narou_n1234');
    });

    test('returns top-level folder name when in a subdirectory', () {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/narou_n1234/subdir',
      );
      addTearDown(container.dispose);

      final novelId = container.read(currentNovelIdProvider);
      expect(novelId, 'narou_n1234');
    });

    test('returns null when no directory is selected', () {
      final container = createContainer(
        libraryPath: '/library',
      );
      addTearDown(container.dispose);

      final novelId = container.read(currentNovelIdProvider);
      expect(novelId, isNull);
    });
  });

  group('bookmarkRepositoryProvider', () {
    test('returns a BookmarkRepository instance', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final repository = container.read(bookmarkRepositoryProvider);
      expect(repository, isA<BookmarkRepository>());
    });
  });

  group('bookmarksForNovelProvider', () {
    test('returns bookmarks for a given novel', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final repository = container.read(bookmarkRepositoryProvider);
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        filePath: '/library/n1234/001_chapter1.txt',
      );

      final bookmarks =
          await container.read(bookmarksForNovelProvider('n1234').future);
      expect(bookmarks.length, 1);
      expect(bookmarks.first.fileName, '001_chapter1.txt');
    });

    test('returns empty list for novel without bookmarks', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final bookmarks =
          await container.read(bookmarksForNovelProvider('n9999').future);
      expect(bookmarks, isEmpty);
    });
  });

  group('isBookmarkedProvider', () {
    test('returns true when file is bookmarked', () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
      );
      addTearDown(container.dispose);

      final repository = container.read(bookmarkRepositoryProvider);
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        filePath: '/library/n1234/001_chapter1.txt',
      );

      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(
                name: '001_chapter1.txt',
                path: '/library/n1234/001_chapter1.txt'),
          );

      final isBookmarked =
          await container.read(isBookmarkedProvider.future);
      expect(isBookmarked, isTrue);
    });

    test('returns false when file is not bookmarked', () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
      );
      addTearDown(container.dispose);

      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(
                name: '001_chapter1.txt',
                path: '/library/n1234/001_chapter1.txt'),
          );

      final isBookmarked =
          await container.read(isBookmarkedProvider.future);
      expect(isBookmarked, isFalse);
    });

    test('returns false when no file is selected', () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
      );
      addTearDown(container.dispose);

      final isBookmarked =
          await container.read(isBookmarkedProvider.future);
      expect(isBookmarked, isFalse);
    });
  });

  group('toggleBookmark', () {
    test('adds bookmark when file is not bookmarked', () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
      );
      addTearDown(container.dispose);

      final repository = container.read(bookmarkRepositoryProvider);

      await toggleBookmark(
        repository,
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        filePath: '/library/n1234/001_chapter1.txt',
        isCurrentlyBookmarked: false,
      );

      final exists = await repository.exists(
        novelId: 'n1234',
        filePath: '/library/n1234/001_chapter1.txt',
      );
      expect(exists, isTrue);
    });

    test('removes bookmark when file is already bookmarked', () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
      );
      addTearDown(container.dispose);

      final repository = container.read(bookmarkRepositoryProvider);
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        filePath: '/library/n1234/001_chapter1.txt',
      );

      await toggleBookmark(
        repository,
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        filePath: '/library/n1234/001_chapter1.txt',
        isCurrentlyBookmarked: true,
      );

      final exists = await repository.exists(
        novelId: 'n1234',
        filePath: '/library/n1234/001_chapter1.txt',
      );
      expect(exists, isFalse);
    });
  });
}
