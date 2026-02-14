import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';

void main() {
  late Directory tempDir;
  late FileSystemService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('novel_viewer_test_');
    service = FileSystemService();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('listTextFiles', () {
    test('returns .txt files in directory', () async {
      File('${tempDir.path}/001_chapter1.txt').writeAsStringSync('content1');
      File('${tempDir.path}/002_chapter2.txt').writeAsStringSync('content2');
      File('${tempDir.path}/image.png').writeAsStringSync('not a text file');

      final files = await service.listTextFiles(tempDir.path);

      expect(files.length, 2);
      expect(files.map((f) => f.name), containsAll(['001_chapter1.txt', '002_chapter2.txt']));
    });

    test('returns empty list for directory with no .txt files', () async {
      File('${tempDir.path}/image.png').writeAsStringSync('not a text file');

      final files = await service.listTextFiles(tempDir.path);

      expect(files, isEmpty);
    });
  });

  group('sortByNumericPrefix', () {
    test('sorts files by numeric prefix in ascending order', () {
      final files = [
        const FileEntry(name: '010_chapter10.txt', path: '/test/010_chapter10.txt'),
        const FileEntry(name: '001_chapter1.txt', path: '/test/001_chapter1.txt'),
        const FileEntry(name: '002_chapter2.txt', path: '/test/002_chapter2.txt'),
      ];

      final sorted = service.sortByNumericPrefix(files);

      expect(sorted.map((f) => f.name).toList(), [
        '001_chapter1.txt',
        '002_chapter2.txt',
        '010_chapter10.txt',
      ]);
    });

    test('places files without numeric prefix after numbered files', () {
      final files = [
        const FileEntry(name: 'readme.txt', path: '/test/readme.txt'),
        const FileEntry(name: '001_chapter1.txt', path: '/test/001_chapter1.txt'),
        const FileEntry(name: '002_chapter2.txt', path: '/test/002_chapter2.txt'),
      ];

      final sorted = service.sortByNumericPrefix(files);

      expect(sorted.map((f) => f.name).toList(), [
        '001_chapter1.txt',
        '002_chapter2.txt',
        'readme.txt',
      ]);
    });

    test('sorts non-numeric files alphabetically', () {
      final files = [
        const FileEntry(name: 'zebra.txt', path: '/test/zebra.txt'),
        const FileEntry(name: 'apple.txt', path: '/test/apple.txt'),
      ];

      final sorted = service.sortByNumericPrefix(files);

      expect(sorted.map((f) => f.name).toList(), [
        'apple.txt',
        'zebra.txt',
      ]);
    });
  });

  group('listSubdirectories', () {
    test('returns subdirectories in directory', () async {
      Directory('${tempDir.path}/novel1').createSync();
      Directory('${tempDir.path}/novel2').createSync();
      File('${tempDir.path}/file.txt').writeAsStringSync('content');

      final dirs = await service.listSubdirectories(tempDir.path);

      expect(dirs.length, 2);
      expect(dirs.map((d) => d.name), containsAll(['novel1', 'novel2']));
    });

    test('DirectoryEntry displayName defaults to name', () {
      const entry = DirectoryEntry(name: 'narou_n1234', path: '/test/narou_n1234');
      expect(entry.displayName, 'narou_n1234');
    });

    test('DirectoryEntry displayName can be overridden', () {
      const entry = DirectoryEntry(
        name: 'narou_n1234',
        path: '/test/narou_n1234',
        displayName: 'テスト小説',
      );
      expect(entry.displayName, 'テスト小説');
    });

    test('returns empty list when no subdirectories exist', () async {
      File('${tempDir.path}/file.txt').writeAsStringSync('content');

      final dirs = await service.listSubdirectories(tempDir.path);

      expect(dirs, isEmpty);
    });
  });
}
