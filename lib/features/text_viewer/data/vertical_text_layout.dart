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

class VerticalHitRegion {
  const VerticalHitRegion({
    required this.charIndex,
    required this.rect,
  });

  final int charIndex;
  final Rect rect;
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

int? hitTestCharIndexFromRegions({
  required Offset localPosition,
  required List<VerticalHitRegion> hitRegions,
  bool snapToNearest = false,
}) {
  if (localPosition.dx < 0 || localPosition.dy < 0) return null;
  if (hitRegions.isEmpty) return null;

  for (final region in hitRegions) {
    if (region.rect.contains(localPosition)) {
      return region.charIndex;
    }
  }

  if (!snapToNearest) return null;

  VerticalHitRegion? nearest;
  var nearestDistanceSquared = double.infinity;
  for (final region in hitRegions) {
    final dx = localPosition.dx < region.rect.left
        ? region.rect.left - localPosition.dx
        : localPosition.dx > region.rect.right
            ? localPosition.dx - region.rect.right
            : 0.0;
    final dy = localPosition.dy < region.rect.top
        ? region.rect.top - localPosition.dy
        : localPosition.dy > region.rect.bottom
            ? localPosition.dy - region.rect.bottom
            : 0.0;

    final distanceSquared = (dx * dx) + (dy * dy);
    if (distanceSquared < nearestDistanceSquared) {
      nearestDistanceSquared = distanceSquared;
      nearest = region;
    }
  }

  return nearest?.charIndex;
}

String extractVerticalSelectedText(
  List<VerticalCharEntry> entries,
  int startIndex,
  int endIndex,
) {
  if (startIndex >= endIndex) return '';

  final start = startIndex.clamp(0, entries.length);
  final end = endIndex.clamp(0, entries.length);

  return entries
      .sublist(start, end)
      .map((e) => e.isNewline ? '\n' : e.text)
      .join();
}
