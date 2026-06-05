import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/features/file_browser/domain/move_follow.dart';

void main() {
  group('followedCurrentDirectory', () {
    test('returns the new source path when current dir is the moved folder', () {
      final result = followedCurrentDirectory(
        currentDir: '/library/narou_n1',
        sourcePath: '/library/narou_n1',
        newSourcePath: '/library/完結済み/narou_n1',
      );

      expect(result, '/library/完結済み/narou_n1');
    });

    test('rebases a descendant of the moved folder under the new path', () {
      final result = followedCurrentDirectory(
        currentDir: '/library/narou_n1/sub',
        sourcePath: '/library/narou_n1',
        newSourcePath: '/library/完結済み/narou_n1',
      );

      expect(p.equals(result!, p.join('/library/完結済み/narou_n1', 'sub')), true);
    });

    test('returns null when current dir is unrelated to the moved folder', () {
      final result = followedCurrentDirectory(
        currentDir: '/library/other',
        sourcePath: '/library/narou_n1',
        newSourcePath: '/library/完結済み/narou_n1',
      );

      expect(result, isNull);
    });

    test('returns null when current dir is null', () {
      final result = followedCurrentDirectory(
        currentDir: null,
        sourcePath: '/library/narou_n1',
        newSourcePath: '/library/完結済み/narou_n1',
      );

      expect(result, isNull);
    });
  });
}
