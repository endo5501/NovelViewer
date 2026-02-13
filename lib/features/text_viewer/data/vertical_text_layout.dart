import 'package:flutter/painting.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';

class VerticalCharEntry {
  final String text;
  final String? rubyText;
  final bool isNewline;
  final bool isRuby;

  VerticalCharEntry.plain(this.text)
      : rubyText = null,
        isNewline = false,
        isRuby = false;

  VerticalCharEntry.newline()
      : text = '\n',
        rubyText = null,
        isNewline = true,
        isRuby = false;

  VerticalCharEntry.ruby(this.text, this.rubyText)
      : isNewline = false,
        isRuby = true;
}

List<VerticalCharEntry> buildVerticalCharEntries(List<TextSegment> segments) {
  final entries = <VerticalCharEntry>[];
  for (final segment in segments) {
    switch (segment) {
      case PlainTextSegment(:final text):
        for (final rune in text.runes) {
          final char = String.fromCharCode(rune);
          if (char == '\n') {
            entries.add(VerticalCharEntry.newline());
          } else {
            entries.add(VerticalCharEntry.plain(char));
          }
        }
      case RubyTextSegment(:final base, :final rubyText):
        entries.add(VerticalCharEntry.ruby(base, rubyText));
    }
  }
  return entries;
}

List<List<int>> buildColumnStructure(List<VerticalCharEntry> entries) {
  final columns = <List<int>>[[]];
  for (var i = 0; i < entries.length; i++) {
    if (entries[i].isNewline) {
      columns.add([]);
    } else {
      columns.last.add(i);
    }
  }
  return columns;
}

int? hitTestCharIndex({
  required Offset localPosition,
  required double availableWidth,
  required double fontSize,
  required double runSpacing,
  required double textHeight,
  required List<List<int>> columns,
}) {
  if (localPosition.dx < 0 || localPosition.dy < 0) return null;
  if (columns.isEmpty) return null;

  final columnWidth = fontSize + runSpacing;
  final charHeight = fontSize * textHeight;

  // RTL: column 0 is at the right edge
  final columnIndex =
      ((availableWidth - localPosition.dx) / columnWidth).floor();
  final rowIndex = (localPosition.dy / charHeight).floor();

  if (columnIndex < 0 || columnIndex >= columns.length) return null;
  if (rowIndex < 0 || rowIndex >= columns[columnIndex].length) return null;

  return columns[columnIndex][rowIndex];
}

String extractVerticalSelectedText(
  List<VerticalCharEntry> entries,
  int startIndex,
  int endIndex,
) {
  // TODO: implement
  return '';
}
