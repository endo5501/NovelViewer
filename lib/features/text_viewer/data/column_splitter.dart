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

  /// A ruby annotation with an EMPTY base text is valid input: hosting sites
  /// publish ruby markup with an empty `rb` element, and the downloader keeps
  /// the element verbatim (see `blockToText`). Such a segment has no character
  /// to feed the kinsoku checks, so [firstChar] and [lastChar] are empty ?
  /// they belong to neither forbidden set, which is exactly the "no check
  /// applies" behaviour we want ? and [charCount] is 0, so the entry occupies
  /// no column space. The entry is still emitted, so the ruby text stays
  /// visible, and the plain-text coordinate space (shared by TTS highlights,
  /// selection offsets and mark matching, all keyed on `base.length`) is
  /// unchanged.
  FlatCharEntry.ruby(RubyTextSegment segment)
      : firstChar = segment.base.isEmpty
            ? ''
            : String.fromCharCode(segment.base.runes.first),
        lastChar = segment.base.isEmpty
            ? ''
            : String.fromCharCode(segment.base.runes.last),
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

/// The first character a reader actually sees at or after [index].
///
/// A ruby annotation with an empty base is a zero-width entry: it carries no
/// character of its own, so the line-head check has to look past it. Reading
/// only `entries[index].firstChar` would let such an entry mask a following
/// forbidden character, which would then open a column despite the kinsoku
/// rule. Entries with a character are returned immediately, so this is a no-op
/// for text without empty-base ruby.
String _lineHeadCharFrom(List<FlatCharEntry> entries, int index) {
  for (var j = index; j < entries.length; j++) {
    if (entries[j].charCount > 0) return entries[j].firstChar;
  }
  return '';
}

/// The last character a reader actually sees in [column], skipping zero-width
/// entries for the same reason as [_lineHeadCharFrom].
String _lineEndCharOf(List<FlatCharEntry> column) {
  for (var j = column.length - 1; j >= 0; j--) {
    if (column[j].charCount > 0) return column[j].lastChar;
  }
  return '';
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
      if (_lineEndCharOf(currentColumn).isLineEndForbidden) {
        moveLastEntryToNext();
        continue;
      }

      // Apply line-head kinsoku: push last char to next column
      // so forbidden char becomes 2nd char, not 1st
      if (_lineHeadCharFrom(entries, i).isLineHeadForbidden &&
          currentColumn.length > 1) {
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
      if (_lineEndCharOf(currentColumn).isLineEndForbidden) {
        moveLastEntryToNext();
        continue;
      }

      // Apply line-head kinsoku: push last char to next column
      // so forbidden char becomes 2nd char, not 1st
      if (_lineHeadCharFrom(entries, i).isLineHeadForbidden &&
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
