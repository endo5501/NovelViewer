import 'package:novel_viewer/features/text_viewer/data/kinsoku.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';

extension on String {
  bool get isLineHeadForbidden => kLineHeadForbidden.contains(this);
  bool get isLineEndForbidden => kLineEndForbidden.contains(this);
}

class FlatCharEntry {
  const FlatCharEntry.plain(this.firstChar)
      : lastChar = firstChar,
        charCount = 1,
        rubySegment = null;

  FlatCharEntry.ruby(RubyTextSegment segment)
      : firstChar = String.fromCharCode(segment.base.runes.first),
        lastChar = String.fromCharCode(segment.base.runes.last),
        charCount = segment.base.runes.length,
        rubySegment = segment;

  final String firstChar;
  final String lastChar;
  final int charCount;
  final RubyTextSegment? rubySegment;

  bool get isRuby => rubySegment != null;
}

List<FlatCharEntry> flattenSegments(List<TextSegment> segments) {
  final entries = <FlatCharEntry>[];
  for (final segment in segments) {
    if (segment case PlainTextSegment(:final text)) {
      for (final rune in text.runes) {
        entries.add(FlatCharEntry.plain(String.fromCharCode(rune)));
      }
    } else if (segment case RubyTextSegment()) {
      entries.add(FlatCharEntry.ruby(segment));
    }
  }
  return entries;
}

List<List<FlatCharEntry>> splitWithKinsoku(
  List<FlatCharEntry> entries,
  int charsPerColumn,
) {
  if (entries.isEmpty) return [];

  final columns = <List<FlatCharEntry>>[];
  var currentColumn = <FlatCharEntry>[];
  var currentCount = 0;
  var i = 0;

  void finalizeColumn() {
    columns.add(currentColumn);
    currentColumn = [];
    currentCount = 0;
  }

  void moveLastEntryToNext() {
    final moved = currentColumn.removeLast();
    currentCount -= moved.charCount;
    finalizeColumn();
    currentColumn = [moved];
    currentCount = moved.charCount;
  }

  while (i < entries.length) {
    final entry = entries[i];
    final wouldExceed = currentCount + entry.charCount > charsPerColumn;
    final hasNext = i < entries.length - 1;

    // Case 1: Adding this entry would exceed the limit
    if (wouldExceed && currentColumn.isNotEmpty) {
      // Apply line-end kinsoku: move opening bracket to next column
      if (currentColumn.last.lastChar.isLineEndForbidden) {
        moveLastEntryToNext();
        continue;
      }

      // Apply line-head kinsoku: push last char to next column
      // so forbidden char becomes 2nd char, not 1st
      if (entry.firstChar.isLineHeadForbidden && currentColumn.length > 1) {
        moveLastEntryToNext();
        continue;
      }

      finalizeColumn();
      continue;
    }

    // Add entry to current column
    currentColumn.add(entry);
    currentCount += entry.charCount;
    i++;

    // Case 2: Column is exactly full or over the limit
    if (currentCount >= charsPerColumn && hasNext) {
      // Apply line-end kinsoku
      if (currentColumn.last.lastChar.isLineEndForbidden) {
        moveLastEntryToNext();
        continue;
      }

      // Apply line-head kinsoku: push last char to next column
      // so forbidden char becomes 2nd char, not 1st
      if (i < entries.length && entries[i].firstChar.isLineHeadForbidden &&
          currentColumn.length > 1) {
        moveLastEntryToNext();
        continue;
      }

      finalizeColumn();
    }
  }

  if (currentColumn.isNotEmpty) {
    finalizeColumn();
  }

  return columns;
}

List<List<TextSegment>> buildColumnsFromEntries(
  List<List<FlatCharEntry>> entryColumns,
) {
  return entryColumns.map(_buildSegmentsFromColumn).toList();
}

List<TextSegment> _buildSegmentsFromColumn(List<FlatCharEntry> column) {
  final segments = <TextSegment>[];
  final plainBuffer = StringBuffer();

  void flushPlainText() {
    if (plainBuffer.isNotEmpty) {
      segments.add(PlainTextSegment(plainBuffer.toString()));
      plainBuffer.clear();
    }
  }

  for (final entry in column) {
    if (entry.isRuby) {
      flushPlainText();
      segments.add(entry.rubySegment!);
    } else {
      plainBuffer.write(entry.firstChar);
    }
  }
  flushPlainText();

  return segments;
}
