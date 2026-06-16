import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

/// One row per `word` in the analysis-history panel, collapsing all existing
/// snapshots for that word (within the active novel's `novel_data.db`) into a
/// single entry. The snapshots list is preserved in ascending
/// `coveredUpToEpisode` order so the copy submenu and snapshot navigator can
/// render them directly.
class HistoryEntry {
  final String word;
  final List<WordSummary> snapshots;
  final String summaryPreview;
  final String? sourceFile;
  final DateTime updatedAt;

  const HistoryEntry({
    required this.word,
    required this.snapshots,
    required this.summaryPreview,
    required this.sourceFile,
    required this.updatedAt,
  });

  int get snapshotCount => snapshots.length;

  bool get isJumpable => sourceFile != null;

  static List<HistoryEntry> mergeRows(List<WordSummary> rows) {
    final grouped = <String, List<WordSummary>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.word, () => []).add(row);
    }

    final entries = grouped.entries.map((entry) {
      final group = [...entry.value]
        ..sort((a, b) => a.coveredUpToEpisode.compareTo(b.coveredUpToEpisode));

      final mostRecent =
          group.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);

      // Jump resolution: search downward from the largest episode and use
      // the first non-null source_file. NULL on the largest snapshot is
      // typically a migrated legacy spoiler row whose source_file was unknown.
      String? resolvedSourceFile;
      for (var i = group.length - 1; i >= 0; i--) {
        final candidate = group[i].sourceFile;
        if (candidate != null) {
          resolvedSourceFile = candidate;
          break;
        }
      }

      return HistoryEntry(
        word: entry.key,
        snapshots: List.unmodifiable(group),
        summaryPreview: mostRecent.summary,
        sourceFile: resolvedSourceFile,
        updatedAt: mostRecent.updatedAt,
      );
    }).toList();

    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }
}
