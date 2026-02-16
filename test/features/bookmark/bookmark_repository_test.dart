import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/bookmark/data/bookmark_repository.dart';
import 'package:novel_viewer/features/bookmark/domain/bookmark.dart';

void main() {
  late NovelDatabase novelDatabase;
  late BookmarkRepository repository;

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
    repository = BookmarkRepository(novelDatabase);
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  group('add', () {
    test('adds a new bookmark', () async {
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        filePath: '/path/to/n1234/001_chapter1.txt',
      );

      final bookmarks = await repository.findByNovel('n1234');
      expect(bookmarks.length, 1);
      expect(bookmarks.first.novelId, 'n1234');
      expect(bookmarks.first.fileName, '001_chapter1.txt');
      expect(bookmarks.first.filePath, '/path/to/n1234/001_chapter1.txt');
      expect(bookmarks.first.createdAt, isNotNull);
    });

    test('ignores duplicate bookmark without error', () async {
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        filePath: '/path/to/n1234/001_chapter1.txt',
      );
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        filePath: '/path/to/n1234/001_chapter1.txt',
      );

      final bookmarks = await repository.findByNovel('n1234');
      expect(bookmarks.length, 1);
    });
  });

  group('remove', () {
    test('removes an existing bookmark', () async {
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        filePath: '/path/to/n1234/001_chapter1.txt',
      );

      await repository.remove(
        novelId: 'n1234',
        filePath: '/path/to/n1234/001_chapter1.txt',
      );

      final bookmarks = await repository.findByNovel('n1234');
      expect(bookmarks, isEmpty);
    });

    test('does nothing for non-existent bookmark', () async {
      await repository.remove(
        novelId: 'n1234',
        filePath: '/path/to/nonexistent.txt',
      );
      // Should complete without error
    });
  });

  group('findByNovel', () {
    test('returns bookmarks ordered by created_at descending', () async {
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        filePath: '/path/to/n1234/001_chapter1.txt',
      );
      // Small delay to ensure different timestamps
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.add(
        novelId: 'n1234',
        fileName: '002_chapter2.txt',
        filePath: '/path/to/n1234/002_chapter2.txt',
      );

      final bookmarks = await repository.findByNovel('n1234');
      expect(bookmarks.length, 2);
      expect(bookmarks[0].fileName, '002_chapter2.txt');
      expect(bookmarks[1].fileName, '001_chapter1.txt');
    });

    test('returns empty list when no bookmarks exist', () async {
      final bookmarks = await repository.findByNovel('n1234');
      expect(bookmarks, isEmpty);
    });

    test('only returns bookmarks for the specified novel', () async {
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        filePath: '/path/to/n1234/001_chapter1.txt',
      );
      await repository.add(
        novelId: 'n5678',
        fileName: '001_chapter1.txt',
        filePath: '/path/to/n5678/001_chapter1.txt',
      );

      final bookmarks = await repository.findByNovel('n1234');
      expect(bookmarks.length, 1);
      expect(bookmarks.first.novelId, 'n1234');
    });
  });

  group('exists', () {
    test('returns true for bookmarked file', () async {
      await repository.add(
        novelId: 'n1234',
        fileName: '001_chapter1.txt',
        filePath: '/path/to/n1234/001_chapter1.txt',
      );

      final result = await repository.exists(
        novelId: 'n1234',
        filePath: '/path/to/n1234/001_chapter1.txt',
      );
      expect(result, isTrue);
    });

    test('returns false for non-bookmarked file', () async {
      final result = await repository.exists(
        novelId: 'n1234',
        filePath: '/path/to/n1234/002_chapter2.txt',
      );
      expect(result, isFalse);
    });
  });

  group('Bookmark model', () {
    test('creates from map', () {
      final bookmark = Bookmark.fromMap({
        'id': 1,
        'novel_id': 'n1234',
        'file_name': '001_chapter1.txt',
        'file_path': '/path/to/n1234/001_chapter1.txt',
        'created_at': '2026-01-01T00:00:00.000',
      });

      expect(bookmark.id, 1);
      expect(bookmark.novelId, 'n1234');
      expect(bookmark.fileName, '001_chapter1.txt');
      expect(bookmark.filePath, '/path/to/n1234/001_chapter1.txt');
      expect(bookmark.createdAt, DateTime(2026, 1, 1));
    });
  });
}
