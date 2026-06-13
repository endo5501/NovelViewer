import 'package:flutter/foundation.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_text_layout.dart';

/// Test-only counter incremented once each time [computeMarkedRanges] runs its
/// buffer scan. F117 collapsed the vertical page's two-pass mark matching
/// (`computeMarkedEntries` + `computeMarkedRanges`) into this single function;
/// F116 then memoizes its result. Tests reset this counter and assert the
/// number of scans per build (F117: exactly one, not two) and across rebuilds
/// (F116: zero when inputs are unchanged).
@visibleForTesting
int computeMarkedRangesCallCount = 0;

/// Identifies a single mark occurrence in vertical layout space.
///
/// All char-entry indices inside one mark occurrence share the same
/// [MarkInfo] instance, so reference equality is a reliable way to detect
/// whether the hover pointer is still inside the same mark.
class MarkInfo {
  const MarkInfo({
    required this.word,
    required this.startEntry,
    required this.endEntry,
    this.style = MarkStyle.solid,
  });

  final String word;
  final int startEntry; // inclusive
  final int endEntry; // exclusive
  final MarkStyle style;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkInfo &&
          other.word == word &&
          other.startEntry == startEntry &&
          other.endEntry == endEntry &&
          other.style == style;

  @override
  int get hashCode => Object.hash(word, startEntry, endEntry, style);
}

/// Returns a map from char-entry index to the [MarkInfo] describing the
/// mark range that entry belongs to. Every entry inside one mark
/// occurrence references the same [MarkInfo] instance.
///
/// Walks the same buffer/positionToEntry structure as `computeMarkedEntries`
/// so the two functions agree on which entries belong to a mark.
///
/// [lineBreakEntryIndices] identifies the newline entries that correspond to
/// real paragraph breaks in the source text. Newline entries NOT in this set
/// are "visual" column-wrap breaks inserted by pagination; they are omitted
/// from the matching buffer so a word straddling a column boundary still
/// matches as a single contiguous span. When the set is null (caller is
/// unaware of the distinction) every newline is treated as a real break, so
/// the legacy boundary behaviour is preserved.
Map<int, MarkInfo> computeMarkedRanges({
  required List<VerticalCharEntry> entries,
  required Map<String, MarkStyle> markedWords,
  Set<int>? lineBreakEntryIndices,
}) {
  computeMarkedRangesCallCount++;
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
  if (marks.isEmpty) return const {};

  final result = <int, MarkInfo>{};
  for (final mark in marks) {
    final startEntry = positionToEntry[mark.start];
    final endEntry = positionToEntry[mark.end - 1] + 1;
    final info = MarkInfo(
      word: mark.word,
      startEntry: startEntry,
      endEntry: endEntry,
      style: mark.style,
    );
    for (var pos = mark.start; pos < mark.end; pos++) {
      result[positionToEntry[pos]] = info;
    }
  }
  return result;
}
