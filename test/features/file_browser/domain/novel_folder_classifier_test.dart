import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/domain/novel_folder_classifier.dart';

void main() {
  group('isNovelFolder', () {
    test('returns true when the folder name is a registered folder_name', () {
      final registered = {'narou_n1234ab', 'kakuyomu_r000001'};

      expect(isNovelFolder('narou_n1234ab', registered), true);
    });

    test('returns false for an unregistered organizational folder', () {
      final registered = {'narou_n1234ab'};

      expect(isNovelFolder('完結済み', registered), false);
    });

    test('returns false when there are no registered novels', () {
      expect(isNovelFolder('narou_n1234ab', const <String>{}), false);
    });

    test('classification is independent of nesting depth (name only)', () {
      // The classifier only ever sees the leaf folder name, so a deeply
      // nested novel folder is recognised the same as a root-level one.
      final registered = {'narou_n5678cd'};

      expect(isNovelFolder('narou_n5678cd', registered), true);
    });
  });
}
