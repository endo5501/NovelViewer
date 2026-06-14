import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/bookmark/data/bookmark_repository.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';

import '../../helpers/novel_metadata_db_fixture.dart';

void main() {
  late NovelDatabase novelDatabase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    final db = await novelDatabase.database;

    // Register the novel folders used by tests that resolve novel ids through
    // [currentNovelIdProvider]. Resolution now keys off the registered
    // folder_name (leaf), so an unregistered path resolves to null.
    Future<void> registerNovel(String folderName) async {
      await db.insert('novels', {
        'site_type': 'narou',
        'novel_id': folderName,
        'title': 'Title $folderName',
        'url': 'https://example.com/$folderName',
        'folder_name': folderName,
        'episode_count': 1,
        'downloaded_at': DateTime.now().toIso8601String(),
      });
    }

    await registerNovel('narou_n1234');
    await registerNovel('n1234');
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
    test('returns null when at library root', () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library',
      );
      addTearDown(container.dispose);

      final novelId = await container.read(currentNovelIdProvider.future);
      expect(novelId, isNull);
    });

    test('returns folder name when inside a registered novel directory',
        () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/narou_n1234',
      );
      addTearDown(container.dispose);

      final novelId = await container.read(currentNovelIdProvider.future);
      expect(novelId, 'narou_n1234');
    });

    test('returns the novel folder name when in a subdirectory', () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/narou_n1234/subdir',
      );
      addTearDown(container.dispose);

      final novelId = await container.read(currentNovelIdProvider.future);
      expect(novelId, 'narou_n1234');
    });

    test('resolves the registered leaf name for a nested novel folder',
        () async {
      // narou_n1234 is registered and nested under the organizational folder
      // "お気に入り". The novel id must be the leaf name, NOT the first segment.
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/お気に入り/narou_n1234',
      );
      addTearDown(container.dispose);

      final novelId = await container.read(currentNovelIdProvider.future);
      expect(novelId, 'narou_n1234');
    });

    test('returns null inside an unregistered organizational folder', () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/お気に入り',
      );
      addTearDown(container.dispose);

      final novelId = await container.read(currentNovelIdProvider.future);
      expect(novelId, isNull);
    });

    test('returns null when no directory is selected', () async {
      final container = createContainer(
        libraryPath: '/library',
      );
      addTearDown(container.dispose);

      final novelId = await container.read(currentNovelIdProvider.future);
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
    test('returns true when file is bookmarked with matching line', () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
      );
      addTearDown(container.dispose);

      final repository = container.read(bookmarkRepositoryProvider);
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        lineNumber: 10,
      );

      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(
                name: '001_chapter1.txt',
                path: '/library/n1234/001_chapter1.txt'),
          );
      container.read(currentViewLineProvider.notifier).set(10);

      // Wait for bookmarkLineNumbersForFileProvider to resolve
      await container.read(bookmarkLineNumbersForFileProvider.future);

      final isBookmarked = container.read(isBookmarkedProvider);
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

      await container.read(bookmarkLineNumbersForFileProvider.future);

      final isBookmarked = container.read(isBookmarkedProvider);
      expect(isBookmarked, isFalse);
    });

    test('returns false when no file is selected', () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
      );
      addTearDown(container.dispose);

      await container.read(bookmarkLineNumbersForFileProvider.future);

      final isBookmarked = container.read(isBookmarkedProvider);
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
        isCurrentlyBookmarked: false,
      );

      final exists = await repository.exists(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
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
      );

      await toggleBookmark(
        repository,
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        isCurrentlyBookmarked: true,
      );

      final exists = await repository.exists(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
      );
      expect(exists, isFalse);
    });

    test('adds bookmark with line number', () async {
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
        isCurrentlyBookmarked: false,
        lineNumber: 42,
      );

      final exists = await repository.exists(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        lineNumber: 42,
      );
      expect(exists, isTrue);
    });

    test('removes bookmark with line number', () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
      );
      addTearDown(container.dispose);

      final repository = container.read(bookmarkRepositoryProvider);
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        lineNumber: 42,
      );

      await toggleBookmark(
        repository,
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        isCurrentlyBookmarked: true,
        lineNumber: 42,
      );

      final exists = await repository.exists(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        lineNumber: 42,
      );
      expect(exists, isFalse);
    });
  });

  group('bookmarkLineNumbersForFileProvider', () {
    test('returns line numbers for bookmarked file', () async {
      final container = createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
      );
      addTearDown(container.dispose);

      final repository = container.read(bookmarkRepositoryProvider);
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        lineNumber: 10,
      );
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        lineNumber: 42,
      );

      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(
                name: '001_chapter1.txt',
                path: '/library/n1234/001_chapter1.txt'),
          );

      final lineNumbers = await container
          .read(bookmarkLineNumbersForFileProvider.future);
      expect(lineNumbers, containsAll([10, 42]));
    });

    test('returns empty list when no bookmarks for file', () async {
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

      final lineNumbers = await container
          .read(bookmarkLineNumbersForFileProvider.future);
      expect(lineNumbers, isEmpty);
    });
  });
}
