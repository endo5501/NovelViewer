import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

void main() {
  group('WordSummary', () {
    test('creates with all fields', () {
      final now = DateTime(2025, 1, 1);
      final summary = WordSummary(
        id: 1,
        folderName: 'my_novel',
        word: 'アリス',
        coveredUpToEpisode: 30,
        summary: 'アリスは主人公の少女である。',
        sourceFile: '030_chapter.txt',
        createdAt: now,
        updatedAt: now,
      );

      expect(summary.id, 1);
      expect(summary.folderName, 'my_novel');
      expect(summary.word, 'アリス');
      expect(summary.coveredUpToEpisode, 30);
      expect(summary.summary, 'アリスは主人公の少女である。');
      expect(summary.sourceFile, '030_chapter.txt');
      expect(summary.createdAt, now);
      expect(summary.updatedAt, now);
    });

    test('source_file may be null (migrated from legacy spoiler row)', () {
      final now = DateTime(2025, 1, 1);
      final summary = WordSummary(
        folderName: 'my_novel',
        word: 'アリス',
        coveredUpToEpisode: 10,
        summary: 'レガシーの要約。',
        sourceFile: null,
        createdAt: now,
        updatedAt: now,
      );

      expect(summary.sourceFile, isNull);
      expect(summary.coveredUpToEpisode, 10);
    });

    test('toMap converts to database map without id', () {
      final now = DateTime(2025, 1, 15, 10, 30);
      final summary = WordSummary(
        id: 1,
        folderName: 'my_novel',
        word: 'アリス',
        coveredUpToEpisode: 40,
        summary: 'アリスは主人公。',
        sourceFile: '040_chapter.txt',
        createdAt: now,
        updatedAt: now,
      );

      final map = summary.toMap();

      expect(map['folder_name'], 'my_novel');
      expect(map['word'], 'アリス');
      expect(map['covered_up_to_episode'], 40);
      expect(map['summary'], 'アリスは主人公。');
      expect(map['source_file'], '040_chapter.txt');
      expect(map['created_at'], now.toIso8601String());
      expect(map['updated_at'], now.toIso8601String());
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('summary_type'), isFalse,
          reason: 'summary_type column is removed in v5');
    });

    test('fromMap creates from database map', () {
      final map = {
        'id': 7,
        'folder_name': 'my_novel',
        'word': 'アリス',
        'covered_up_to_episode': 40,
        'summary': 'アリスは少女。',
        'source_file': '040_chapter.txt',
        'created_at': '2025-01-15T10:30:00.000',
        'updated_at': '2025-01-15T10:30:00.000',
      };

      final summary = WordSummary.fromMap(map);

      expect(summary.id, 7);
      expect(summary.folderName, 'my_novel');
      expect(summary.word, 'アリス');
      expect(summary.coveredUpToEpisode, 40);
      expect(summary.summary, 'アリスは少女。');
      expect(summary.sourceFile, '040_chapter.txt');
      expect(summary.createdAt, DateTime.parse('2025-01-15T10:30:00.000'));
      expect(summary.updatedAt, DateTime.parse('2025-01-15T10:30:00.000'));
    });

    test('fromMap accepts null source_file', () {
      final map = {
        'id': 8,
        'folder_name': 'my_novel',
        'word': 'アリス',
        'covered_up_to_episode': 10,
        'summary': 'レガシー要約。',
        'source_file': null,
        'created_at': '2025-01-15T10:30:00.000',
        'updated_at': '2025-01-15T10:30:00.000',
      };

      final summary = WordSummary.fromMap(map);

      expect(summary.sourceFile, isNull);
      expect(summary.coveredUpToEpisode, 10);
    });
  });
}
