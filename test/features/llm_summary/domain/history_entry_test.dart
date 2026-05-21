import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

WordSummary _summary({
  required String folderName,
  required String word,
  required SummaryType type,
  required String summary,
  String? sourceFile,
  required DateTime updatedAt,
}) {
  return WordSummary(
    folderName: folderName,
    word: word,
    summaryType: type,
    summary: summary,
    sourceFile: sourceFile,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

void main() {
  group('HistoryEntry.mergeRows', () {
    test('produces single entry for word with only no-spoiler row', () {
      final rows = [
        _summary(
          folderName: 'my_novel',
          word: 'ボブ',
          type: SummaryType.noSpoiler,
          summary: 'ボブは主人公の友人。',
          sourceFile: '040_chapter.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries, hasLength(1));
      expect(entries.first.word, 'ボブ');
      expect(entries.first.type, HistoryEntryType.noSpoilerOnly);
      expect(entries.first.summaryPreview, 'ボブは主人公の友人。');
      expect(entries.first.sourceFile, '040_chapter.txt');
      expect(entries.first.updatedAt, DateTime.utc(2026, 5, 20, 10));
    });

    test('produces single entry for word with only spoiler row', () {
      final rows = [
        _summary(
          folderName: 'my_novel',
          word: '聖印',
          type: SummaryType.spoiler,
          summary: '神聖な刻印。',
          sourceFile: '050_chapter.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 11),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries, hasLength(1));
      expect(entries.first.type, HistoryEntryType.spoilerOnly);
      expect(entries.first.summaryPreview, '神聖な刻印。');
      expect(entries.first.sourceFile, '050_chapter.txt');
    });

    test('merges two rows of the same word into a single "both" entry', () {
      final rows = [
        _summary(
          folderName: 'my_novel',
          word: 'アリス',
          type: SummaryType.noSpoiler,
          summary: 'アリスは少女。',
          sourceFile: '040_chapter.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
        _summary(
          folderName: 'my_novel',
          word: 'アリス',
          type: SummaryType.spoiler,
          summary: 'アリスは王女。',
          sourceFile: '060_chapter.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 16),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries, hasLength(1));
      expect(entries.first.word, 'アリス');
      expect(entries.first.type, HistoryEntryType.both);
    });

    test('"both" entry uses latest updated_at across the two rows', () {
      final rows = [
        _summary(
          folderName: 'my_novel',
          word: 'アリス',
          type: SummaryType.noSpoiler,
          summary: 'なし要約',
          sourceFile: '040_chapter.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
        _summary(
          folderName: 'my_novel',
          word: 'アリス',
          type: SummaryType.spoiler,
          summary: 'あり要約',
          sourceFile: '060_chapter.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 16),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries.first.updatedAt, DateTime.utc(2026, 5, 20, 16));
    });

    test('"both" entry prefers no-spoiler summary as preview', () {
      final rows = [
        _summary(
          folderName: 'my_novel',
          word: 'アリス',
          type: SummaryType.noSpoiler,
          summary: 'なし要約',
          sourceFile: '040_chapter.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
        _summary(
          folderName: 'my_novel',
          word: 'アリス',
          type: SummaryType.spoiler,
          summary: 'あり要約',
          sourceFile: '060_chapter.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 16),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries.first.summaryPreview, 'なし要約');
    });

    test(
        'sourceFile resolution: prefers no_spoiler, falls back to spoiler, '
        'null when neither has it', () {
      final rows = [
        // Both rows have source_file → prefer no_spoiler
        _summary(
          folderName: 'f',
          word: 'A_word',
          type: SummaryType.noSpoiler,
          summary: 'a',
          sourceFile: 'a_no.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
        _summary(
          folderName: 'f',
          word: 'A_word',
          type: SummaryType.spoiler,
          summary: 'a',
          sourceFile: 'a_sp.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 11),
        ),
        // Only spoiler has source_file → use spoiler
        _summary(
          folderName: 'f',
          word: 'B_word',
          type: SummaryType.spoiler,
          summary: 'b',
          sourceFile: 'b_sp.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 12),
        ),
        // Spoiler-only with NULL source_file → null
        _summary(
          folderName: 'f',
          word: 'C_word',
          type: SummaryType.spoiler,
          summary: 'c',
          sourceFile: null,
          updatedAt: DateTime.utc(2026, 5, 20, 13),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);
      final byWord = {for (final e in entries) e.word: e};

      expect(byWord['A_word']!.sourceFile, 'a_no.txt');
      expect(byWord['B_word']!.sourceFile, 'b_sp.txt');
      expect(byWord['C_word']!.sourceFile, isNull);
    });

    test('returns entries sorted by updated_at descending', () {
      final rows = [
        _summary(
          folderName: 'f',
          word: 'middle',
          type: SummaryType.spoiler,
          summary: 'm',
          updatedAt: DateTime.utc(2026, 5, 20, 12),
        ),
        _summary(
          folderName: 'f',
          word: 'old',
          type: SummaryType.spoiler,
          summary: 'o',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
        _summary(
          folderName: 'f',
          word: 'new',
          type: SummaryType.spoiler,
          summary: 'n',
          updatedAt: DateTime.utc(2026, 5, 20, 14),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries.map((e) => e.word).toList(), ['new', 'middle', 'old']);
    });

    test('isJumpable is true when sourceFile is non-null, false otherwise',
        () {
      final rows = [
        _summary(
          folderName: 'f',
          word: 'jumpable',
          type: SummaryType.spoiler,
          summary: 'a',
          sourceFile: 'x.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
        _summary(
          folderName: 'f',
          word: 'legacy',
          type: SummaryType.spoiler,
          summary: 'b',
          sourceFile: null,
          updatedAt: DateTime.utc(2026, 5, 20, 11),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);
      final byWord = {for (final e in entries) e.word: e};

      expect(byWord['jumpable']!.isJumpable, isTrue);
      expect(byWord['legacy']!.isJumpable, isFalse);
    });
  });
}
