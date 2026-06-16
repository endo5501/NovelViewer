import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/features/bookmark/data/bookmark_repository.dart';
import 'package:novel_viewer/features/bookmark/domain/bookmark.dart';

import '../../helpers/novel_data_db_fixture.dart';

void main() {
  late Database db;
  late BookmarkRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openInMemoryNovelDataDb();
    repository = BookmarkRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('add', () {
    test('adds a new bookmark', () async {
      await repository.add(fileName: '001_chapter1.txt');

      final bookmarks = await repository.findAll();
      expect(bookmarks.length, 1);
      expect(bookmarks.first.fileName, '001_chapter1.txt');
      expect(bookmarks.first.createdAt, isNotNull);
    });

    test('ignores duplicate bookmark without error', () async {
      await repository.add(fileName: '001_chapter1.txt');
      await repository.add(fileName: '001_chapter1.txt');

      final bookmarks = await repository.findAll();
      expect(bookmarks.length, 1);
    });
  });

  group('remove', () {
    test('removes an existing bookmark', () async {
      await repository.add(fileName: '001_chapter1.txt');

      await repository.remove(fileName: '001_chapter1.txt');

      final bookmarks = await repository.findAll();
      expect(bookmarks, isEmpty);
    });

    test('does nothing for non-existent bookmark', () async {
      await repository.remove(fileName: 'nonexistent.txt');
      // Should complete without error
    });
  });

  group('findAll', () {
    test('returns bookmarks ordered by created_at descending', () async {
      await repository.add(fileName: '001_chapter1.txt');
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.add(fileName: '002_chapter2.txt');

      final bookmarks = await repository.findAll();
      expect(bookmarks.length, 2);
      expect(bookmarks[0].fileName, '002_chapter2.txt');
      expect(bookmarks[1].fileName, '001_chapter1.txt');
    });

    test('returns empty list when no bookmarks exist', () async {
      final bookmarks = await repository.findAll();
      expect(bookmarks, isEmpty);
    });
  });

  group('exists', () {
    test('returns true for bookmarked file', () async {
      await repository.add(fileName: '001_chapter1.txt');

      final result = await repository.exists(fileName: '001_chapter1.txt');
      expect(result, isTrue);
    });

    test('returns false for non-bookmarked file', () async {
      final result = await repository.exists(fileName: '002_chapter2.txt');
      expect(result, isFalse);
    });
  });

  group('add with lineNumber', () {
    test('adds a bookmark with line number', () async {
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 42);

      final bookmarks = await repository.findAll();
      expect(bookmarks.length, 1);
      expect(bookmarks.first.lineNumber, 42);
    });

    test('allows different lines in same file', () async {
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 42);
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 100);

      final bookmarks = await repository.findAll();
      expect(bookmarks.length, 2);
    });

    test('ignores duplicate same file and line', () async {
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 42);
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 42);

      final bookmarks = await repository.findAll();
      expect(bookmarks.length, 1);
    });
  });

  group('remove with lineNumber', () {
    test('removes bookmark at specific line', () async {
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 42);
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 100);

      await repository.remove(fileName: '001_chapter1.txt', lineNumber: 42);

      final bookmarks = await repository.findAll();
      expect(bookmarks.length, 1);
      expect(bookmarks.first.lineNumber, 100);
    });
  });

  group('exists with lineNumber', () {
    test('returns true for bookmarked file and line', () async {
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 42);

      final result = await repository.exists(
        fileName: '001_chapter1.txt',
        lineNumber: 42,
      );
      expect(result, isTrue);
    });

    test('returns false for different line', () async {
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 42);

      final result = await repository.exists(
        fileName: '001_chapter1.txt',
        lineNumber: 50,
      );
      expect(result, isFalse);
    });
  });

  group('findByFile', () {
    test('returns bookmarks for specific file ordered by line', () async {
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 10);
      await repository.add(fileName: '001_chapter1.txt', lineNumber: 42);
      await repository.add(fileName: '002_chapter2.txt', lineNumber: 5);

      final bookmarks =
          await repository.findByFile(fileName: '001_chapter1.txt');
      expect(bookmarks.length, 2);
      expect(bookmarks[0].lineNumber, 10);
      expect(bookmarks[1].lineNumber, 42);
    });

    test('returns empty list for file with no bookmarks', () async {
      final bookmarks =
          await repository.findByFile(fileName: 'nonexistent.txt');
      expect(bookmarks, isEmpty);
    });
  });

  group('Bookmark model', () {
    test('creates from map', () {
      final bookmark = Bookmark.fromMap({
        'id': 1,
        'file_name': '001_chapter1.txt',
        'created_at': '2026-01-01T00:00:00.000',
      });

      expect(bookmark.id, 1);
      expect(bookmark.fileName, '001_chapter1.txt');
      expect(bookmark.createdAt, DateTime(2026, 1, 1));
    });

    test('creates from map with line_number', () {
      final bookmark = Bookmark.fromMap({
        'id': 1,
        'file_name': '001_chapter1.txt',
        'line_number': 42,
        'created_at': '2026-01-01T00:00:00.000',
      });

      expect(bookmark.lineNumber, 42);
    });

    test('toMap includes line_number and no novel_id / file_path', () {
      final bookmark = Bookmark(
        fileName: '001_chapter1.txt',
        lineNumber: 42,
        createdAt: DateTime(2026, 1, 1),
      );

      final map = bookmark.toMap();
      expect(map['line_number'], 42);
      expect(map.containsKey('novel_id'), isFalse);
      expect(map.containsKey('file_path'), isFalse);
    });
  });
}
