import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';

void main() {
  group('ReadingProgress', () {
    test('constructs from required fields', () {
      final progress = ReadingProgress(
        novelId: 'narou_n1234ab',
        filePath: '/library/narou_n1234ab/001_chapter1.txt',
        fileName: '001_chapter1.txt',
        updatedAt: DateTime(2026, 5, 26, 12, 0, 0),
      );

      expect(progress.novelId, 'narou_n1234ab');
      expect(progress.filePath, '/library/narou_n1234ab/001_chapter1.txt');
      expect(progress.fileName, '001_chapter1.txt');
      expect(progress.updatedAt, DateTime(2026, 5, 26, 12, 0, 0));
    });

    test('toMap produces canonical column shape', () {
      final progress = ReadingProgress(
        novelId: 'narou_n1234ab',
        filePath: '/library/narou_n1234ab/003_chapter3.txt',
        fileName: '003_chapter3.txt',
        updatedAt: DateTime.utc(2026, 5, 26, 12, 0, 0),
      );

      final map = progress.toMap();
      expect(map['novel_id'], 'narou_n1234ab');
      expect(map['file_path'], '/library/narou_n1234ab/003_chapter3.txt');
      expect(map['file_name'], '003_chapter3.txt');
      expect(map['updated_at'], '2026-05-26T12:00:00.000Z');
    });

    test('fromMap rehydrates fields', () {
      final progress = ReadingProgress.fromMap({
        'novel_id': 'kakuyomu_1689',
        'file_path': '/library/kakuyomu_1689/010_chapter10.txt',
        'file_name': '010_chapter10.txt',
        'updated_at': '2026-05-26T12:00:00.000Z',
      });

      expect(progress.novelId, 'kakuyomu_1689');
      expect(progress.filePath, '/library/kakuyomu_1689/010_chapter10.txt');
      expect(progress.fileName, '010_chapter10.txt');
      expect(progress.updatedAt, DateTime.utc(2026, 5, 26, 12, 0, 0));
    });

    test('fromMap round-trips through toMap', () {
      final original = ReadingProgress(
        novelId: 'narou_n1234ab',
        filePath: '/library/narou_n1234ab/005_chapter5.txt',
        fileName: '005_chapter5.txt',
        updatedAt: DateTime.utc(2026, 5, 26, 12, 0, 0),
      );

      final rehydrated = ReadingProgress.fromMap(original.toMap());

      expect(rehydrated.novelId, original.novelId);
      expect(rehydrated.filePath, original.filePath);
      expect(rehydrated.fileName, original.fileName);
      expect(rehydrated.updatedAt, original.updatedAt);
    });
  });
}
