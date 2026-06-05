import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  group('listOrganizationalFolderTree', () {
    test('returns organizational folders recursively, skipping novel folders',
        () async {
      Directory('${tempDir.path}/完結済み').createSync();
      Directory('${tempDir.path}/完結済み/2024').createSync();
      Directory('${tempDir.path}/連載中').createSync();
      // A novel folder must not be descended into.
      final novel = Directory('${tempDir.path}/narou_n1')..createSync();
      Directory('${novel.path}/should_not_appear').createSync();
      File('${novel.path}/001.txt').writeAsStringSync('x');

      final paths = await service.listOrganizationalFolderTree(
        tempDir.path,
        {'narou_n1'},
      );

      final names = paths.map((path) => p.basename(path)).toSet();
      expect(names, containsAll(<String>['完結済み', '2024', '連載中']));
      expect(names, isNot(contains('narou_n1')));
      expect(names, isNot(contains('should_not_appear')));
    });

    test('returns empty list when there are no organizational folders',
        () async {
      Directory('${tempDir.path}/narou_n1').createSync();

      final paths = await service.listOrganizationalFolderTree(
        tempDir.path,
        {'narou_n1'},
      );

      expect(paths, isEmpty);
    });
  });

  group('createDirectory', () {
    test('creates a directory with a valid name', () async {
      final entry = await service.createDirectory(tempDir.path, '完結済み');

      expect(entry.name, '完結済み');
      expect(Directory(entry.path).existsSync(), true);
      expect(p.equals(entry.path, p.join(tempDir.path, '完結済み')), true);
    });

    test('throws nameCollision when a directory with the same name exists',
        () async {
      Directory('${tempDir.path}/連載中').createSync();

      expect(
        () => service.createDirectory(tempDir.path, '連載中'),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.nameCollision)),
      );
    });

    test('throws nameCollision when a file with the same name exists',
        () async {
      File('${tempDir.path}/memo').writeAsStringSync('x');

      expect(
        () => service.createDirectory(tempDir.path, 'memo'),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.nameCollision)),
      );
    });

    test('throws invalidName when the name contains invalid characters',
        () async {
      expect(
        () => service.createDirectory(tempDir.path, 'a/b'),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.invalidName)),
      );
    });

    test('throws invalidName when the name is blank', () async {
      expect(
        () => service.createDirectory(tempDir.path, '   '),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.invalidName)),
      );
    });
  });

  group('renameDirectory', () {
    test('renames a directory in place to a new valid name', () async {
      final src = Directory('${tempDir.path}/old')..createSync();
      File('${src.path}/keep.txt').writeAsStringSync('x');

      final entry = await service.renameDirectory(src.path, 'new');

      expect(entry.name, 'new');
      expect(src.existsSync(), false);
      expect(Directory(p.join(tempDir.path, 'new')).existsSync(), true);
      expect(File(p.join(tempDir.path, 'new', 'keep.txt')).existsSync(), true);
    });

    test('throws nameCollision when target name already exists', () async {
      Directory('${tempDir.path}/old').createSync();
      Directory('${tempDir.path}/taken').createSync();

      expect(
        () => service.renameDirectory('${tempDir.path}/old', 'taken'),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.nameCollision)),
      );
    });

    test('throws invalidName when the new name is invalid', () async {
      Directory('${tempDir.path}/old').createSync();

      expect(
        () => service.renameDirectory('${tempDir.path}/old', 'a:b'),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.invalidName)),
      );
    });

    test('throws sourceNotFound when the directory does not exist', () async {
      expect(
        () => service.renameDirectory('${tempDir.path}/missing', 'new'),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.sourceNotFound)),
      );
    });
  });

  group('moveDirectory', () {
    test('moves a directory into the destination keeping its leaf name',
        () async {
      final src = Directory('${tempDir.path}/narou_n1234')..createSync();
      File('${src.path}/001.txt').writeAsStringSync('content');
      final dest = Directory('${tempDir.path}/完結済み')..createSync();

      final newPath = await service.moveDirectory(src.path, dest.path);

      expect(src.existsSync(), false);
      expect(p.basename(newPath), 'narou_n1234');
      expect(p.equals(newPath, p.join(dest.path, 'narou_n1234')), true);
      expect(Directory(newPath).existsSync(), true);
      expect(File(p.join(newPath, '001.txt')).existsSync(), true);
    });

    test('moves the folder-local tts_audio.db along with the folder', () async {
      final src = Directory('${tempDir.path}/narou_n1234')..createSync();
      File('${src.path}/tts_audio.db').writeAsStringSync('audio-data');
      final dest = Directory('${tempDir.path}/完結済み')..createSync();

      final newPath = await service.moveDirectory(src.path, dest.path);

      final movedDb = File(p.join(newPath, 'tts_audio.db'));
      expect(movedDb.existsSync(), true);
      expect(movedDb.readAsStringSync(), 'audio-data');
      // Leaf name preserved keeps the DB folder_name keys valid.
      expect(p.basename(newPath), 'narou_n1234');
    });

    test('throws nameCollision when destination already has same leaf name',
        () async {
      final src = Directory('${tempDir.path}/narou_n1234')..createSync();
      final dest = Directory('${tempDir.path}/完結済み')..createSync();
      Directory('${dest.path}/narou_n1234').createSync();

      expect(
        () => service.moveDirectory(src.path, dest.path),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.nameCollision)),
      );
    });

    test('throws intoSelfOrDescendant when moving into itself', () async {
      final src = Directory('${tempDir.path}/folder')..createSync();

      expect(
        () => service.moveDirectory(src.path, src.path),
        throwsA(isA<DirectoryOpException>().having(
            (e) => e.error, 'error', DirectoryOpError.intoSelfOrDescendant)),
      );
    });

    test('throws intoSelfOrDescendant when moving into a descendant', () async {
      final src = Directory('${tempDir.path}/parent')..createSync();
      final child = Directory('${src.path}/child')..createSync();

      expect(
        () => service.moveDirectory(src.path, child.path),
        throwsA(isA<DirectoryOpException>().having(
            (e) => e.error, 'error', DirectoryOpError.intoSelfOrDescendant)),
      );
    });

    test('throws sourceNotFound when the source does not exist', () async {
      final dest = Directory('${tempDir.path}/dest')..createSync();

      expect(
        () => service.moveDirectory('${tempDir.path}/missing', dest.path),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.sourceNotFound)),
      );
    });

    test('normalizes a raw filesystem failure into ioFailure', () async {
      // Destination parent does not exist, so Directory.rename raises a
      // FileSystemException that must surface as a DirectoryOpException.
      final src = Directory('${tempDir.path}/narou_n1234')..createSync();

      expect(
        () => service.moveDirectory(
            src.path, '${tempDir.path}/does_not_exist'),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.ioFailure)),
      );
    });
  });

  group('deleteEmptyDirectory', () {
    test('deletes an empty directory', () async {
      final dir = Directory('${tempDir.path}/empty')..createSync();

      await service.deleteEmptyDirectory(dir.path);

      expect(dir.existsSync(), false);
    });

    test('throws notEmpty when the directory contains a file', () async {
      final dir = Directory('${tempDir.path}/withfile')..createSync();
      File('${dir.path}/a.txt').writeAsStringSync('x');

      expect(
        () => service.deleteEmptyDirectory(dir.path),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.notEmpty)),
      );
      expect(dir.existsSync(), true);
    });

    test('throws notEmpty when the directory contains a subfolder', () async {
      final dir = Directory('${tempDir.path}/withsub')..createSync();
      Directory('${dir.path}/sub').createSync();

      expect(
        () => service.deleteEmptyDirectory(dir.path),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.notEmpty)),
      );
    });

    test('throws sourceNotFound when the directory does not exist', () async {
      expect(
        () => service.deleteEmptyDirectory('${tempDir.path}/missing'),
        throwsA(isA<DirectoryOpException>()
            .having((e) => e.error, 'error', DirectoryOpError.sourceNotFound)),
      );
    });
  });

  group('deleteDirectory', () {
    test('deletes directory and all contents recursively', () async {
      final novelDir = Directory('${tempDir.path}/narou_n1234');
      novelDir.createSync();
      File('${novelDir.path}/001_chapter1.txt').writeAsStringSync('content1');
      File('${novelDir.path}/002_chapter2.txt').writeAsStringSync('content2');

      await service.deleteDirectory(novelDir.path);

      expect(novelDir.existsSync(), false);
    });

    test('deletes empty directory', () async {
      final emptyDir = Directory('${tempDir.path}/empty');
      emptyDir.createSync();

      await service.deleteDirectory(emptyDir.path);

      expect(emptyDir.existsSync(), false);
    });

    test('throws when directory does not exist', () async {
      expect(
        () => service.deleteDirectory('${tempDir.path}/nonexistent'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
