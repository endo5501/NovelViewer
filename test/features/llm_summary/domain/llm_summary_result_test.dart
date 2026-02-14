import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

void main() {
  group('SummaryType', () {
    test('has two values: spoiler and noSpoiler', () {
      expect(SummaryType.values.length, 2);
      expect(SummaryType.values, contains(SummaryType.spoiler));
      expect(SummaryType.values, contains(SummaryType.noSpoiler));
    });
  });

  group('WordSummary', () {
    test('creates with all fields', () {
      final now = DateTime(2025, 1, 1);
      final summary = WordSummary(
        id: 1,
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
        summary: 'アリスは主人公の少女である。',
        sourceFile: null,
        createdAt: now,
        updatedAt: now,
      );

      expect(summary.id, 1);
      expect(summary.folderName, 'my_novel');
      expect(summary.word, 'アリス');
      expect(summary.summaryType, SummaryType.spoiler);
      expect(summary.summary, 'アリスは主人公の少女である。');
      expect(summary.sourceFile, null);
      expect(summary.createdAt, now);
      expect(summary.updatedAt, now);
    });

    test('creates no-spoiler summary with sourceFile', () {
      final now = DateTime(2025, 1, 1);
      final summary = WordSummary(
        id: 2,
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.noSpoiler,
        summary: 'アリスは物語の序盤で登場する少女。',
        sourceFile: '040_chapter.txt',
        createdAt: now,
        updatedAt: now,
      );

      expect(summary.summaryType, SummaryType.noSpoiler);
      expect(summary.sourceFile, '040_chapter.txt');
    });

    test('toMap converts to database map', () {
      final now = DateTime(2025, 1, 15, 10, 30);
      final summary = WordSummary(
        id: 1,
        folderName: 'my_novel',
        word: 'アリス',
        summaryType: SummaryType.spoiler,
        summary: 'アリスは主人公。',
        sourceFile: null,
        createdAt: now,
        updatedAt: now,
      );

      final map = summary.toMap();

      expect(map['folder_name'], 'my_novel');
      expect(map['word'], 'アリス');
      expect(map['summary_type'], 'spoiler');
      expect(map['summary'], 'アリスは主人公。');
      expect(map['source_file'], null);
      expect(map['created_at'], now.toIso8601String());
      expect(map['updated_at'], now.toIso8601String());
      expect(map.containsKey('id'), false);
    });

    test('fromMap creates from database map', () {
      final map = {
        'id': 1,
        'folder_name': 'my_novel',
        'word': 'アリス',
        'summary_type': 'no_spoiler',
        'summary': 'アリスは少女。',
        'source_file': '040_chapter.txt',
        'created_at': '2025-01-15T10:30:00.000',
        'updated_at': '2025-01-15T10:30:00.000',
      };

      final summary = WordSummary.fromMap(map);

      expect(summary.id, 1);
      expect(summary.folderName, 'my_novel');
      expect(summary.word, 'アリス');
      expect(summary.summaryType, SummaryType.noSpoiler);
      expect(summary.summary, 'アリスは少女。');
      expect(summary.sourceFile, '040_chapter.txt');
    });
  });
}
