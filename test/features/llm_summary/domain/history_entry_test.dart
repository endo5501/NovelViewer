import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

WordSummary _snap({
  required String folderName,
  required String word,
  required int episode,
  required String summary,
  String? sourceFile,
  required DateTime updatedAt,
}) =>
    WordSummary(
      folderName: folderName,
      word: word,
      coveredUpToEpisode: episode,
      summary: summary,
      sourceFile: sourceFile,
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );

void main() {
  group('HistoryEntry.mergeRows', () {
    test('one snapshot per word produces one entry with snapshotCount=1', () {
      final rows = [
        _snap(
          folderName: 'my_novel',
          word: 'ボブ',
          episode: 40,
          summary: 'ボブは主人公の友人。',
          sourceFile: '040_chapter.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries, hasLength(1));
      expect(entries.first.word, 'ボブ');
      expect(entries.first.snapshotCount, 1);
      expect(entries.first.summaryPreview, 'ボブは主人公の友人。');
      expect(entries.first.sourceFile, '040_chapter.txt');
      expect(entries.first.updatedAt, DateTime.utc(2026, 5, 20, 10));
      expect(entries.first.snapshots, hasLength(1));
    });

    test('multiple snapshots for the same word collapse into one entry', () {
      final rows = [
        _snap(
          folderName: 'my_novel',
          word: 'アリス',
          episode: 30,
          summary: '序盤の要約',
          sourceFile: '030_chapter.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
        _snap(
          folderName: 'my_novel',
          word: 'アリス',
          episode: 60,
          summary: '中盤の要約',
          sourceFile: '060_chapter.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 16),
        ),
        _snap(
          folderName: 'my_novel',
          word: 'アリス',
          episode: 120,
          summary: '全話要約',
          sourceFile: '120_chapter.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 18),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries, hasLength(1));
      expect(entries.first.word, 'アリス');
      expect(entries.first.snapshotCount, 3);
      expect(
          entries.first.snapshots.map((s) => s.coveredUpToEpisode).toList(),
          [30, 60, 120],
          reason: 'snapshots SHALL be ordered ascending by episode');
    });

    test('updatedAt is the latest across all snapshots', () {
      final rows = [
        _snap(
          folderName: 'my_novel',
          word: 'アリス',
          episode: 30,
          summary: 'a',
          sourceFile: '030.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
        _snap(
          folderName: 'my_novel',
          word: 'アリス',
          episode: 60,
          summary: 'b',
          sourceFile: '060.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 16),
        ),
        _snap(
          folderName: 'my_novel',
          word: 'アリス',
          episode: 120,
          summary: 'c',
          sourceFile: '120.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 12),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries.first.updatedAt, DateTime.utc(2026, 5, 20, 16));
    });

    test('summaryPreview comes from the most recently updated snapshot', () {
      final rows = [
        _snap(
          folderName: 'my_novel',
          word: 'アリス',
          episode: 30,
          summary: '古い要約',
          sourceFile: '030.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
        _snap(
          folderName: 'my_novel',
          word: 'アリス',
          episode: 60,
          summary: '新しい要約',
          sourceFile: '060.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 16),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries.first.summaryPreview, '新しい要約');
    });

    test(
        'sourceFile resolution: pick non-null source_file from the largest '
        'coveredUpToEpisode downward', () {
      final rows = [
        // Largest episode but source_file is NULL → fall back
        _snap(
          folderName: 'f',
          word: 'W',
          episode: 120,
          summary: 'c',
          sourceFile: null,
          updatedAt: DateTime.utc(2026, 5, 20, 18),
        ),
        // Next largest episode has source_file → use this
        _snap(
          folderName: 'f',
          word: 'W',
          episode: 60,
          summary: 'b',
          sourceFile: '060.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 16),
        ),
        _snap(
          folderName: 'f',
          word: 'W',
          episode: 30,
          summary: 'a',
          sourceFile: '030.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries.first.sourceFile, '060.txt');
    });

    test('sourceFile is null when every snapshot has source_file=null', () {
      final rows = [
        _snap(
          folderName: 'f',
          word: 'legacy',
          episode: 10,
          summary: 'a',
          sourceFile: null,
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
        _snap(
          folderName: 'f',
          word: 'legacy',
          episode: 1,
          summary: 'b',
          sourceFile: null,
          updatedAt: DateTime.utc(2026, 5, 20, 11),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries.first.sourceFile, isNull);
      expect(entries.first.isJumpable, isFalse);
    });

    test('isJumpable is true when sourceFile resolves to non-null', () {
      final rows = [
        _snap(
          folderName: 'f',
          word: 'jumpable',
          episode: 5,
          summary: 'x',
          sourceFile: 'x.txt',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
      ];

      final entry = HistoryEntry.mergeRows(rows).single;

      expect(entry.isJumpable, isTrue);
    });

    test('returns entries sorted by updatedAt descending across words', () {
      final rows = [
        _snap(
          folderName: 'f',
          word: 'middle',
          episode: 10,
          summary: 'm',
          updatedAt: DateTime.utc(2026, 5, 20, 12),
        ),
        _snap(
          folderName: 'f',
          word: 'old',
          episode: 5,
          summary: 'o',
          updatedAt: DateTime.utc(2026, 5, 20, 10),
        ),
        _snap(
          folderName: 'f',
          word: 'new',
          episode: 1,
          summary: 'n',
          updatedAt: DateTime.utc(2026, 5, 20, 14),
        ),
      ];

      final entries = HistoryEntry.mergeRows(rows);

      expect(entries.map((e) => e.word).toList(), ['new', 'middle', 'old']);
    });
  });
}
