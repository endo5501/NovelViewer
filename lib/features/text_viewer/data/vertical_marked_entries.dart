import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_text_layout.dart';

/// Returns a map from char-entry index to [MarkStyle] for every entry whose
/// base text falls inside a mark range derived from [markedWords].
///
/// [lineBreakEntryIndices] identifies the newline entries that correspond to
/// real paragraph breaks. Newline entries NOT in this set are "visual"
/// column-wrap breaks and are omitted from the matching buffer so a word
/// straddling a column boundary keeps its styling on both sides. When the set
/// is null every newline is treated as a real break (legacy behaviour).
Map<int, MarkStyle> computeMarkedEntries({
  required List<VerticalCharEntry> entries,
  required Map<String, MarkStyle> markedWords,
  Set<int>? lineBreakEntryIndices,
}) {
  if (markedWords.isEmpty) return const {};

  final buffer = StringBuffer();
  final positionToEntry = <int>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    if (entry.isNewline) {
      final isRealBreak =
          lineBreakEntryIndices == null || lineBreakEntryIndices.contains(i);
      if (!isRealBreak) continue; // visual column wrap — keep word contiguous
      buffer.write('\n');
      positionToEntry.add(i);
      continue;
    }
    final text = entry.text;
    for (var c = 0; c < text.length; c++) {
      buffer.write(text[c]);
      positionToEntry.add(i);
    }
  }

  final marks = findMarks(text: buffer.toString(), wordsByStyle: markedWords);

  final result = <int, MarkStyle>{};
  for (final mark in marks) {
    for (var pos = mark.start; pos < mark.end; pos++) {
      result[positionToEntry[pos]] = mark.style;
    }
  }
  return result;
}
