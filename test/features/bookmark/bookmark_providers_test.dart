import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/bookmark/data/bookmark_repository.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/shared/database/novel_data_database.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry_provider.dart';

import 'package:path/path.dart' as p;

import '../../helpers/novel_data_db_fixture.dart';
import '../../helpers/novel_metadata_db_fixture.dart';

/// Builds a path under `/library` using the host path separators, so it matches
/// what `resolveNovelFolderPath` (which joins via `package:path`) returns on
/// every platform — avoiding `/` vs `\` mismatches on Windows.
String lib([String? a, String? b]) => p.joinAll([
      '/library',
      if (a != null) a,
      if (b != null) b,
    ]);

void main() {
  late NovelDatabase novelDatabase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    final db = await novelDatabase.database;

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

  /// Builds a container, optionally wiring the current novel's `novel_data.db`
  /// to a fresh in-memory database so the folder-scoped bookmark repository
  /// resolves without touching the filesystem.
  Future<({ProviderContainer container, NovelDataDatabase? novelData})>
      createContainer({
    String? libraryPath,
    String? currentDirectory,
    String? seededFolderPath,
  }) async {
    NovelDataDatabase? novelData;
    final overrides = [
      novelDatabaseProvider.overrideWithValue(novelDatabase),
      libraryPathProvider.overrideWithValue(libraryPath ?? '/library'),
      if (currentDirectory != null)
        currentDirectoryProvider.overrideWith(
            () => CurrentDirectoryNotifier(currentDirectory)),
    ];
    if (seededFolderPath != null) {
      // Back every per-folder novel_data.db handle with one shared in-memory
      // database, so the folder-scoped repository resolves regardless of how
      // the folder path is spelled/normalized — no filesystem access.
      final inMemory = await openInMemoryNovelDataDb();
      final registry = PerFolderDbRegistry(
        novelDataFactory: (_) => NovelDataDatabase('unused')
          ..setDatabase(inMemory),
      );
      novelData = registry.novelData(seededFolderPath);
      overrides.add(perFolderDbRegistryProvider.overrideWithValue(registry));
    }
    final container = ProviderContainer(overrides: overrides);
    return (container: container, novelData: novelData);
  }

  group('currentNovelFolderPathProvider', () {
    test('returns null when at library root', () async {
      final c = await createContainer(
        libraryPath: '/library',
        currentDirectory: '/library',
      );
      addTearDown(c.container.dispose);

      final path =
          await c.container.read(currentNovelFolderPathProvider.future);
      expect(path, isNull);
    });

    test('returns the folder path when inside a registered novel directory',
        () async {
      final c = await createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/narou_n1234',
      );
      addTearDown(c.container.dispose);

      final path =
          await c.container.read(currentNovelFolderPathProvider.future);
      expect(path, lib('narou_n1234'));
    });

    test('returns the novel folder path when in a subdirectory', () async {
      final c = await createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/narou_n1234/subdir',
      );
      addTearDown(c.container.dispose);

      final path =
          await c.container.read(currentNovelFolderPathProvider.future);
      expect(path, lib('narou_n1234'));
    });

    test('resolves the registered folder path for a nested novel folder',
        () async {
      final c = await createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/お気に入り/narou_n1234',
      );
      addTearDown(c.container.dispose);

      final path =
          await c.container.read(currentNovelFolderPathProvider.future);
      expect(path, lib('お気に入り', 'narou_n1234'));
    });

    test('returns null inside an unregistered organizational folder', () async {
      final c = await createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/お気に入り',
      );
      addTearDown(c.container.dispose);

      final path =
          await c.container.read(currentNovelFolderPathProvider.future);
      expect(path, isNull);
    });

    test('returns null when no directory is selected', () async {
      final c = await createContainer(libraryPath: '/library');
      addTearDown(c.container.dispose);

      final path =
          await c.container.read(currentNovelFolderPathProvider.future);
      expect(path, isNull);
    });
  });

  group('bookmarkRepositoryProvider', () {
    test('returns a BookmarkRepository bound to the folder db', () async {
      final c = await createContainer(seededFolderPath: lib('n1234'));
      addTearDown(c.container.dispose);

      final repository = await c.container
          .read(bookmarkRepositoryProvider(lib('n1234')).future);
      expect(repository, isA<BookmarkRepository>());
    });
  });

  group('bookmarksForCurrentNovelProvider', () {
    test('returns bookmarks for the current novel', () async {
      final c = await createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
        seededFolderPath: lib('n1234'),
      );
      addTearDown(c.container.dispose);

      final repository = await c.container
          .read(bookmarkRepositoryProvider(lib('n1234')).future);
      await repository.add(fileName: '001_chapter1.txt');

      final bookmarks =
          await c.container.read(bookmarksForCurrentNovelProvider.future);
      expect(bookmarks.length, 1);
      expect(bookmarks.first.fileName, '001_chapter1.txt');
    });

    test('returns empty list when not inside a novel', () async {
      final c = await createContainer(
        libraryPath: '/library',
        currentDirectory: '/library',
      );
      addTearDown(c.container.dispose);

      final bookmarks =
          await c.container.read(bookmarksForCurrentNovelProvider.future);
      expect(bookmarks, isEmpty);
    });
  });

  group('isBookmarkedProvider', () {
    test('returns true when file is bookmarked with matching line', () async {
      final c = await createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
        seededFolderPath: lib('n1234'),
      );
      addTearDown(c.container.dispose);

      final repository = await c.container
          .read(bookmarkRepositoryProvider(lib('n1234')).future);
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 10);

      c.container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(
                name: '001_chapter1.txt',
                path: '/library/n1234/001_chapter1.txt'),
          );
      c.container.read(currentViewLineProvider.notifier).set(10);

      await c.container.read(bookmarkLineNumbersForFileProvider.future);

      expect(c.container.read(isBookmarkedProvider), isTrue);
    });

    test('returns false when file is not bookmarked', () async {
      final c = await createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
        seededFolderPath: lib('n1234'),
      );
      addTearDown(c.container.dispose);

      c.container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(
                name: '001_chapter1.txt',
                path: '/library/n1234/001_chapter1.txt'),
          );

      await c.container.read(bookmarkLineNumbersForFileProvider.future);

      expect(c.container.read(isBookmarkedProvider), isFalse);
    });
  });

  group('toggleBookmark', () {
    test('adds then removes a bookmark', () async {
      final c = await createContainer(seededFolderPath: lib('n1234'));
      addTearDown(c.container.dispose);

      final repository = await c.container
          .read(bookmarkRepositoryProvider(lib('n1234')).future);

      await toggleBookmark(
        repository,
        fileName: '001_chapter1.txt',
        isCurrentlyBookmarked: false,
        lineNumber: 42,
      );
      expect(
        await repository.exists(fileName: '001_chapter1.txt', lineNumber: 42),
        isTrue,
      );

      await toggleBookmark(
        repository,
        fileName: '001_chapter1.txt',
        isCurrentlyBookmarked: true,
        lineNumber: 42,
      );
      expect(
        await repository.exists(fileName: '001_chapter1.txt', lineNumber: 42),
        isFalse,
      );
    });
  });

  group('bookmarkLineNumbersForFileProvider', () {
    test('returns line numbers for bookmarked file', () async {
      final c = await createContainer(
        libraryPath: '/library',
        currentDirectory: '/library/n1234',
        seededFolderPath: lib('n1234'),
      );
      addTearDown(c.container.dispose);

      final repository = await c.container
          .read(bookmarkRepositoryProvider(lib('n1234')).future);
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 10);
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 42);

      c.container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(
                name: '001_chapter1.txt',
                path: '/library/n1234/001_chapter1.txt'),
          );

      final lineNumbers =
          await c.container.read(bookmarkLineNumbersForFileProvider.future);
      expect(lineNumbers, containsAll([10, 42]));
    });
  });
}
