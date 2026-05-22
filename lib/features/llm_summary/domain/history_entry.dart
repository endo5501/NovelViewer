import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

enum HistoryEntryType { noSpoilerOnly, spoilerOnly, both }

class HistoryEntry {
  final String folderName;
  final String word;
  final HistoryEntryType type;
  final String summaryPreview;
  final String? sourceFile;
  final DateTime updatedAt;

  const HistoryEntry({
    required this.folderName,
    required this.word,
    required this.type,
    required this.summaryPreview,
    required this.sourceFile,
    required this.updatedAt,
  });

  bool get isJumpable => sourceFile != null;

  static List<HistoryEntry> mergeRows(List<WordSummary> rows) {
    final grouped = <({String folder, String word}), List<WordSummary>>{};
    for (final row in rows) {
      grouped
          .putIfAbsent((folder: row.folderName, word: row.word), () => [])
          .add(row);
    }

    final entries = grouped.entries.map((entry) {
      final group = entry.value;
      final noSpoiler = _firstOfType(group, SummaryType.noSpoiler);
      final spoiler = _firstOfType(group, SummaryType.spoiler);

      final HistoryEntryType type;
      if (noSpoiler != null && spoiler != null) {
        type = HistoryEntryType.both;
      } else if (noSpoiler != null) {
        type = HistoryEntryType.noSpoilerOnly;
      } else {
        type = HistoryEntryType.spoilerOnly;
      }

      final preview = noSpoiler?.summary ?? spoiler!.summary;
      final sourceFile = noSpoiler?.sourceFile ?? spoiler?.sourceFile;
      final updatedAt = [noSpoiler?.updatedAt, spoiler?.updatedAt]
          .whereType<DateTime>()
          .reduce((a, b) => a.isAfter(b) ? a : b);

      return HistoryEntry(
        folderName: entry.key.folder,
        word: entry.key.word,
        type: type,
        summaryPreview: preview,
        sourceFile: sourceFile,
        updatedAt: updatedAt,
      );
    }).toList();

    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }
}

WordSummary? _firstOfType(List<WordSummary> rows, SummaryType type) {
  for (final r in rows) {
    if (r.summaryType == type) return r;
  }
  return null;
}
