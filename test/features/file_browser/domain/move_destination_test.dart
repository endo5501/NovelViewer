import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/domain/move_destination.dart';

void main() {
  group('buildMoveDestinations', () {
    test('includes the library root as the first destination', () {
      final dests = buildMoveDestinations(
        libraryPath: '/library',
        organizationalFolderPaths: const [],
        sourcePath: '/library/narou_n1',
      );

      expect(dests.first.path, '/library');
      expect(dests.first.depth, 0);
    });

    test('includes organizational folders with nesting depth', () {
      final dests = buildMoveDestinations(
        libraryPath: '/library',
        organizationalFolderPaths: const [
          '/library/完結済み',
          '/library/完結済み/2024',
          '/library/連載中',
        ],
        sourcePath: '/library/narou_n1',
      );

      final byPath = {for (final d in dests) d.path: d};
      expect(byPath.keys, containsAll(<String>[
        '/library',
        '/library/完結済み',
        '/library/完結済み/2024',
        '/library/連載中',
      ]));
      expect(byPath['/library/完結済み']!.depth, 1);
      expect(byPath['/library/完結済み/2024']!.depth, 2);
    });

    test('excludes the source folder itself', () {
      final dests = buildMoveDestinations(
        libraryPath: '/library',
        organizationalFolderPaths: const [
          '/library/完結済み',
        ],
        sourcePath: '/library/完結済み',
      );

      expect(dests.map((d) => d.path), isNot(contains('/library/完結済み')));
      expect(dests.map((d) => d.path), contains('/library'));
    });

    test('excludes descendants of the source folder', () {
      final dests = buildMoveDestinations(
        libraryPath: '/library',
        organizationalFolderPaths: const [
          '/library/完結済み',
          '/library/完結済み/2024',
        ],
        sourcePath: '/library/完結済み',
      );

      final paths = dests.map((d) => d.path).toList();
      expect(paths, isNot(contains('/library/完結済み')));
      expect(paths, isNot(contains('/library/完結済み/2024')));
    });

    test('destinations are ordered with parents before their children', () {
      final dests = buildMoveDestinations(
        libraryPath: '/library',
        organizationalFolderPaths: const [
          '/library/完結済み/2024',
          '/library/完結済み',
        ],
        sourcePath: '/library/narou_n1',
      );

      final paths = dests.map((d) => d.path).toList();
      expect(paths.indexOf('/library/完結済み'),
          lessThan(paths.indexOf('/library/完結済み/2024')));
    });
  });
}
