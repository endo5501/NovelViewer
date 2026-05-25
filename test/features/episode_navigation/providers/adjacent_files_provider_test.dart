import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/providers/adjacent_files_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

class _StubSelectedFileNotifier extends SelectedFileNotifier {
  final FileEntry? _initial;
  _StubSelectedFileNotifier(this._initial);

  @override
  FileEntry? build() => _initial;
}

List<FileEntry> _files(int count) {
  return List.generate(
    count,
    (i) => FileEntry(
      name: '${(i + 1).toString().padLeft(3, '0')}-ep${i + 1}.txt',
      path: '/library/novel/${(i + 1).toString().padLeft(3, '0')}-ep${i + 1}.txt',
    ),
  );
}

ProviderContainer _makeContainer({
  required List<FileEntry> files,
  FileEntry? selected,
}) {
  return ProviderContainer(
    overrides: [
      directoryContentsProvider.overrideWith((ref) async {
        return DirectoryContents(files: files, subdirectories: const []);
      }),
      selectedFileProvider
          .overrideWith(() => _StubSelectedFileNotifier(selected)),
    ],
  );
}

void main() {
  group('adjacentFilesProvider', () {
    test('returns next and previous for a middle selection', () async {
      final files = _files(5);
      final container = _makeContainer(files: files, selected: files[2]);
      addTearDown(container.dispose);

      // Ensure directory contents are loaded before reading the derived provider.
      await container.read(directoryContentsProvider.future);

      final adjacent = container.read(adjacentFilesProvider);
      expect(adjacent.prev, files[1]);
      expect(adjacent.next, files[3]);
    });

    test('first selection: next is second file, prev is null', () async {
      final files = _files(5);
      final container = _makeContainer(files: files, selected: files.first);
      addTearDown(container.dispose);

      await container.read(directoryContentsProvider.future);

      final adjacent = container.read(adjacentFilesProvider);
      expect(adjacent.prev, isNull);
      expect(adjacent.next, files[1]);
    });

    test('last selection: prev is fourth, next is null', () async {
      final files = _files(5);
      final container = _makeContainer(files: files, selected: files.last);
      addTearDown(container.dispose);

      await container.read(directoryContentsProvider.future);

      final adjacent = container.read(adjacentFilesProvider);
      expect(adjacent.prev, files[3]);
      expect(adjacent.next, isNull);
    });

    test('only-one-file selection: both null', () async {
      final files = _files(1);
      final container = _makeContainer(files: files, selected: files.first);
      addTearDown(container.dispose);

      await container.read(directoryContentsProvider.future);

      final adjacent = container.read(adjacentFilesProvider);
      expect(adjacent.prev, isNull);
      expect(adjacent.next, isNull);
    });

    test('no selection: both null', () async {
      final files = _files(5);
      final container = _makeContainer(files: files, selected: null);
      addTearDown(container.dispose);

      await container.read(directoryContentsProvider.future);

      final adjacent = container.read(adjacentFilesProvider);
      expect(adjacent.prev, isNull);
      expect(adjacent.next, isNull);
    });

    test('selected file not in directory listing: both null', () async {
      final files = _files(5);
      const orphan = FileEntry(
        name: '999-orphan.txt',
        path: '/elsewhere/999-orphan.txt',
      );
      final container = _makeContainer(files: files, selected: orphan);
      addTearDown(container.dispose);

      await container.read(directoryContentsProvider.future);

      final adjacent = container.read(adjacentFilesProvider);
      expect(adjacent.prev, isNull);
      expect(adjacent.next, isNull);
    });

    test('empty directory listing: both null', () async {
      final container = _makeContainer(files: const [], selected: null);
      addTearDown(container.dispose);

      await container.read(directoryContentsProvider.future);

      final adjacent = container.read(adjacentFilesProvider);
      expect(adjacent.prev, isNull);
      expect(adjacent.next, isNull);
    });
  });

  group('AdjacentFiles equality', () {
    test('equal instances compare equal', () {
      const a = FileEntry(name: 'a.txt', path: '/x/a.txt');
      const b = FileEntry(name: 'b.txt', path: '/x/b.txt');
      const x = AdjacentFiles(prev: a, next: b);
      const y = AdjacentFiles(prev: a, next: b);
      expect(x, equals(y));
      expect(x.hashCode, equals(y.hashCode));
    });

    test('different instances do not compare equal', () {
      const a = FileEntry(name: 'a.txt', path: '/x/a.txt');
      const b = FileEntry(name: 'b.txt', path: '/x/b.txt');
      const x = AdjacentFiles(prev: a, next: b);
      const y = AdjacentFiles(prev: null, next: b);
      expect(x, isNot(equals(y)));
    });
  });
}
