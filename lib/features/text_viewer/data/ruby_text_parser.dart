import 'dart:math' show max, min;

import 'package:flutter/services.dart' show TextSelection;

import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';

final _rubyPattern = RegExp(
  r'<ruby>(?:<rb>)?(.*?)(?:</rb>)?(?:<rp>.*?</rp>)?<rt>(.*?)</rt>(?:<rp>.*?</rp>)?</ruby>',
);

List<TextSegment> parseRubyText(String content) {
  if (content.isEmpty) return [];

  final segments = <TextSegment>[];
  var lastEnd = 0;

  for (final match in _rubyPattern.allMatches(content)) {
    if (match.start > lastEnd) {
      segments.add(PlainTextSegment(content.substring(lastEnd, match.start)));
    }
    segments.add(RubyTextSegment(
      base: match.group(1)!,
      rubyText: match.group(2)!,
    ));
    lastEnd = match.end;
  }

  if (lastEnd < content.length) {
    segments.add(PlainTextSegment(content.substring(lastEnd)));
  }

  return segments;
}

/// Extracts selected text from segments using display offsets.
///
/// In SelectableText.rich, WidgetSpan counts as 1 character (U+FFFC),
/// so selection offsets don't match plainText offsets. This function
/// maps display offsets to actual text content.
String extractSelectedText(
  int start,
  int end,
  List<TextSegment> segments,
) {
  if (start >= end) return '';

  final buffer = StringBuffer();
  var displayOffset = 0;

  for (final segment in segments) {
    final displayLen = switch (segment) {
      PlainTextSegment(:final text) => text.length,
      RubyTextSegment() => 1,
    };
    final segStart = displayOffset;
    final segEnd = displayOffset + displayLen;

    if (end <= segStart) break;
    if (start < segEnd && end > segStart) {
      switch (segment) {
        case PlainTextSegment(:final text):
          final localStart = (start - segStart).clamp(0, text.length);
          final localEnd = (end - segStart).clamp(0, text.length);
          if (localStart < localEnd) {
            buffer.write(text.substring(localStart, localEnd));
          }
        case RubyTextSegment(:final base):
          buffer.write(base);
      }
    }
    displayOffset = segEnd;
  }

  return buffer.toString();
}

/// Converts a [TextSelection] from `SelectableText.rich` (which uses display
/// offsets where each WidgetSpan counts as one U+FFFC character) into the
/// underlying text with ruby base expanded. Returns the empty string for
/// invalid or collapsed selections.
String selectedTextFromSelection(
  TextSelection selection,
  List<TextSegment> segments,
) {
  if (!selection.isValid || selection.isCollapsed) return '';
  final start = min(selection.start, selection.end);
  final end = max(selection.start, selection.end);
  return extractSelectedText(start, end, segments);
}

String buildPlainText(List<TextSegment> segments) {
  final buffer = StringBuffer();
  for (final segment in segments) {
    switch (segment) {
      case PlainTextSegment(:final text):
        buffer.write(text);
      case RubyTextSegment(:final base):
        buffer.write(base);
    }
  }
  return buffer.toString();
}
