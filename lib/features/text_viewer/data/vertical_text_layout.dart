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

/// Extracts the original (unmapped) text for the selected entry range.
///
/// [lineBreakEntryIndices] identifies the newline entries that correspond to
/// real paragraph breaks. Newline entries NOT in this set are "visual"
/// column-wrap breaks inserted by pagination; they contribute no character so
/// a word straddling a column boundary is extracted as a continuous string
/// (which then matches when sent for re-analysis). When the set is null every
/// newline is emitted as `'\n'` (legacy behaviour).
/// Converts a char-entry index into a page-local plain-text offset.
///
/// The plain-text coordinate space is the page's text with ruby replaced by
/// its base text — the space used by `TextSegment.offset`, the TTS highlight
/// range, and `tts_segments.text_offset`. Counting rules match
/// `VerticalTextPage._computeTtsHighlights`, which walks the same entries in
/// the opposite direction:
///
/// - a plain or ruby entry advances by `entry.text.length` (code units, so a
///   surrogate pair counts as 2 even though it is a single entry)
/// - a newline entry listed in [lineBreakEntryIndices] is a real paragraph
///   break and advances by 1
/// - any other newline entry is a visual column wrap inserted by pagination
///   and advances by 0
///
/// [lineBreakEntryIndices] is required rather than nullable: an absent set
/// would make every newline ambiguous, and the two plausible defaults produce
/// different offsets.
///
/// The result is page-local. Callers holding a paginated page must add the
/// page's `pageStartTextOffset` to obtain a document-global offset.
int plainTextOffsetFromEntryIndex(
  List<VerticalCharEntry> entries,
  int entryIndex, {
  required Set<int> lineBreakEntryIndices,
}) {
  if (entryIndex <= 0) return 0;
  final end = entryIndex.clamp(0, entries.length);

  var offset = 0;
  for (var i = 0; i < end; i++) {
    final entry = entries[i];
    if (entry.isNewline) {
      if (lineBreakEntryIndices.contains(i)) offset += 1;
      continue;
    }
    offset += entry.text.length;
  }
  return offset;
}

String extractVerticalSelectedText(
  List<VerticalCharEntry> entries,
  int startIndex,
  int endIndex, {
  Set<int>? lineBreakEntryIndices,
}) {
  if (startIndex >= endIndex) return '';

  final start = startIndex.clamp(0, entries.length);
  final end = endIndex.clamp(0, entries.length);

  final buffer = StringBuffer();
  for (var i = start; i < end; i++) {
    final entry = entries[i];
    if (entry.isNewline) {
      final isRealBreak =
          lineBreakEntryIndices == null || lineBreakEntryIndices.contains(i);
      if (isRealBreak) buffer.write('\n');
      continue;
    }
    buffer.write(entry.text);
  }
  return buffer.toString();
}
