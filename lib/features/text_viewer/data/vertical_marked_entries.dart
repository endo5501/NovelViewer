import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_text_layout.dart';

/// Returns a map from char-entry index to [MarkStyle] for every entry whose
/// base text falls inside a mark range derived from [markedWords].
Map<int, MarkStyle> computeMarkedEntries({
  required List<VerticalCharEntry> entries,
  required Map<String, MarkStyle> markedWords,
}) {
  if (markedWords.isEmpty) return const {};

  final buffer = StringBuffer();
  final positionToEntry = <int>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    if (entry.isNewline) {
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
