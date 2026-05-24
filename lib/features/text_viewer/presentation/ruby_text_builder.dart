import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';

typedef OnMarkEnter = void Function(String word, Offset position);
typedef OnMarkExit = void Function(String word);

class RubyTextWidget extends StatelessWidget {
  const RubyTextWidget({
    super.key,
    required this.base,
    required this.rubyText,
    required this.baseStyle,
    this.query,
    this.localMarks = const [],
    this.onMarkEnter,
    this.onMarkExit,
  });

  final String base;
  final String rubyText;
  final TextStyle? baseStyle;
  final String? query;

  /// Mark spans expressed in segment-local coordinates (positions inside
  /// [base]). Computed by [buildRubyTextSpans] from the full-text mark scan.
  final List<MarkSpan> localMarks;

  final OnMarkEnter? onMarkEnter;
  final OnMarkExit? onMarkExit;

  @override
  Widget build(BuildContext context) {
    final fontSize = baseStyle?.fontSize ?? 14.0;
    final rubyFontSize = fontSize * 0.5;
    final brightness = Theme.of(context).brightness;

    final basePieceStyle = baseStyle?.copyWith(height: 1.0);
    final initialSpans = (query != null && query!.isNotEmpty)
        ? _buildHighlightedPlainSpans(
            base,
            query!,
            basePieceStyle,
            brightness: brightness,
          )
        : <InlineSpan>[TextSpan(text: base, style: basePieceStyle)];
    final markedSpans = localMarks.isEmpty
        ? initialSpans
        : _applyLocalMarksToSpans(
            initialSpans,
            localMarks,
            onMarkEnter: onMarkEnter,
            onMarkExit: onMarkExit,
          );
    final baseWidget = (markedSpans.length == 1 &&
            markedSpans.first is TextSpan &&
            (markedSpans.first as TextSpan).children == null)
        ? Text.rich(markedSpans.first as TextSpan)
        : Text.rich(TextSpan(children: markedSpans));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rubyText,
          style: baseStyle?.copyWith(
            fontSize: rubyFontSize,
            height: 1.0,
          ),
        ),
        baseWidget,
      ],
    );
  }
}

final _ttsHighlightColor = Colors.green.withValues(alpha: 0.3);

Color searchHighlightBackground(Brightness brightness) =>
    brightness == Brightness.dark ? Colors.amber.shade700 : Colors.yellow;

Color? searchHighlightForeground(Brightness brightness) =>
    brightness == Brightness.dark ? Colors.black : null;

TextSpan buildRubyTextSpans(
  List<TextSegment> segments,
  TextStyle? baseStyle,
  String? query, {
  TextRange? ttsHighlightRange,
  Brightness brightness = Brightness.light,
  Map<String, MarkStyle> markedWords = const {},
  OnMarkEnter? onMarkEnter,
  OnMarkExit? onMarkExit,
}) {
  if (segments.isEmpty) {
    return const TextSpan();
  }

  final hasQuery = query != null && query.isNotEmpty;
  final hasTts = ttsHighlightRange != null;
  // Marks are computed over the FULL base text (plain segments + ruby base
  // text) so a cached word that straddles a segment boundary still matches.
  final globalMarks = markedWords.isEmpty
      ? const <MarkSpan>[]
      : findMarks(
          text: _concatenatedBaseText(segments),
          wordsByStyle: markedWords,
        );
  final spans = <InlineSpan>[];
  var plainTextOffset = 0;

  for (final segment in segments) {
    switch (segment) {
      case PlainTextSegment(:final text):
        final List<InlineSpan> renderedSpans;
        if (hasQuery) {
          renderedSpans = _buildHighlightedPlainSpans(text, query, baseStyle,
              ttsRange: ttsHighlightRange,
              textOffset: plainTextOffset,
              brightness: brightness);
        } else if (hasTts) {
          renderedSpans = _buildTtsHighlightedSpans(
              text, baseStyle, ttsHighlightRange, plainTextOffset);
        } else {
          renderedSpans = [TextSpan(text: text, style: baseStyle)];
        }
        final segmentMarks = _localizeMarks(
            globalMarks, plainTextOffset, text.length);
        if (segmentMarks.isNotEmpty) {
          spans.addAll(_applyLocalMarksToSpans(
            renderedSpans,
            segmentMarks,
            onMarkEnter: onMarkEnter,
            onMarkExit: onMarkExit,
          ));
        } else {
          spans.addAll(renderedSpans);
        }
        plainTextOffset += text.length;
      case RubyTextSegment(:final base, :final rubyText):
        final segmentMarks =
            _localizeMarks(globalMarks, plainTextOffset, base.length);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: RubyTextWidget(
            base: base,
            rubyText: rubyText,
            baseStyle: baseStyle,
            query: hasQuery ? query : null,
            localMarks: segmentMarks,
            onMarkEnter: onMarkEnter,
            onMarkExit: onMarkExit,
          ),
        ));
        plainTextOffset += base.length;
    }
  }

  return TextSpan(style: baseStyle, children: spans);
}

String _concatenatedBaseText(List<TextSegment> segments) {
  final buf = StringBuffer();
  for (final s in segments) {
    switch (s) {
      case PlainTextSegment(:final text):
        buf.write(text);
      case RubyTextSegment(:final base):
        buf.write(base);
    }
  }
  return buf.toString();
}

/// Returns the subset of [globalMarks] that intersect the segment range
/// `[segmentStart, segmentStart + segmentLength)`, with positions translated
/// to local coordinates inside that segment (clamped to `[0, segmentLength]`).
List<MarkSpan> _localizeMarks(
  List<MarkSpan> globalMarks,
  int segmentStart,
  int segmentLength,
) {
  final segmentEnd = segmentStart + segmentLength;
  final result = <MarkSpan>[];
  for (final m in globalMarks) {
    if (m.end <= segmentStart || m.start >= segmentEnd) continue;
    final localStart = (m.start - segmentStart).clamp(0, segmentLength);
    final localEnd = (m.end - segmentStart).clamp(0, segmentLength);
    result.add(MarkSpan(
      start: localStart,
      end: localEnd,
      style: m.style,
      word: m.word,
    ));
  }
  return result;
}

/// Splits [renderedSpans] at the boundaries of any mark in [localMarks] (in
/// segment-local coordinates) and adds underline decoration to spans that
/// fall inside a mark. When [onMarkEnter] / [onMarkExit] are supplied, the
/// emitted marked sub-spans also carry hover handlers that report the
/// underlying [MarkSpan.word] to the caller.
List<InlineSpan> _applyLocalMarksToSpans(
  List<InlineSpan> renderedSpans,
  List<MarkSpan> localMarks, {
  OnMarkEnter? onMarkEnter,
  OnMarkExit? onMarkExit,
}) {
  if (localMarks.isEmpty) return renderedSpans;

  final markByPos = <int, MarkSpan>{};
  for (final m in localMarks) {
    for (var i = m.start; i < m.end; i++) {
      markByPos[i] = m;
    }
  }

  final output = <InlineSpan>[];
  var positionInSegment = 0;
  for (final span in renderedSpans) {
    if (span is! TextSpan || span.text == null) {
      output.add(span);
      continue;
    }
    final text = span.text!;
    // Walk character by character within this span, grouping runs by mark
    // (or no-mark). A boundary occurs whenever the underlying MarkSpan
    // identity changes — that way two adjacent marks of the same style but
    // different words still split into separate hover-targets.
    var runStart = 0;
    MarkSpan? runMark = markByPos[positionInSegment];
    for (var i = 1; i <= text.length; i++) {
      final pos = positionInSegment + i;
      final markHere = i < text.length ? markByPos[pos] : null;
      final isBoundary = i == text.length || !identical(markHere, runMark);
      if (isBoundary) {
        final subText = text.substring(runStart, i);
        if (runMark == null) {
          output.add(TextSpan(text: subText, style: span.style));
        } else {
          final markStyle = span.style?.copyWith(
                decoration: TextDecoration.underline,
                decorationStyle: _decorationStyleFor(runMark.style),
              ) ??
              TextStyle(
                decoration: TextDecoration.underline,
                decorationStyle: _decorationStyleFor(runMark.style),
              );
          final word = runMark.word;
          output.add(TextSpan(
            text: subText,
            style: markStyle,
            mouseCursor: onMarkEnter != null || onMarkExit != null
                ? SystemMouseCursors.help
                : MouseCursor.defer,
            onEnter: onMarkEnter == null
                ? null
                : (PointerEnterEvent event) =>
                    onMarkEnter(word, event.position),
            onExit: onMarkExit == null
                ? null
                : (PointerExitEvent _) => onMarkExit(word),
          ));
        }
        runStart = i;
        runMark = markHere;
      }
    }
    positionInSegment += text.length;
  }
  return output;
}

TextDecorationStyle _decorationStyleFor(MarkStyle style) => switch (style) {
      MarkStyle.dotted => TextDecorationStyle.dotted,
      MarkStyle.solid => TextDecorationStyle.solid,
    };

List<TextSpan> _buildHighlightedPlainSpans(
  String text,
  String query,
  TextStyle? baseStyle, {
  TextRange? ttsRange,
  int textOffset = 0,
  Brightness brightness = Brightness.light,
}) {
  final queryLower = query.toLowerCase();
  final textLower = text.toLowerCase();
  final bgColor = searchHighlightBackground(brightness);
  final fgColor = searchHighlightForeground(brightness);
  final searchHighlightStyle =
      baseStyle?.copyWith(backgroundColor: bgColor, color: fgColor) ??
          TextStyle(backgroundColor: bgColor, color: fgColor);
  final spans = <TextSpan>[];
  var start = 0;

  var index = textLower.indexOf(queryLower, start);
  while (index != -1) {
    if (index > start) {
      // Non-search region: apply TTS highlight if applicable
      spans.addAll(_applyTtsHighlight(
          text.substring(start, index), baseStyle, ttsRange,
          textOffset + start));
    }
    // Search highlight takes priority over TTS
    spans.add(TextSpan(
      text: text.substring(index, index + query.length),
      style: searchHighlightStyle,
    ));
    start = index + query.length;
    index = textLower.indexOf(queryLower, start);
  }

  if (start < text.length) {
    spans.addAll(_applyTtsHighlight(
        text.substring(start), baseStyle, ttsRange, textOffset + start));
  } else if (spans.isEmpty) {
    spans.addAll(_applyTtsHighlight(text, baseStyle, ttsRange, textOffset));
  }

  return spans;
}

List<TextSpan> _buildTtsHighlightedSpans(
  String text,
  TextStyle? baseStyle,
  TextRange ttsRange,
  int textOffset,
) {
  return _applyTtsHighlight(text, baseStyle, ttsRange, textOffset);
}

List<TextSpan> _applyTtsHighlight(
  String text,
  TextStyle? baseStyle,
  TextRange? ttsRange,
  int textOffset,
) {
  if (text.isEmpty) return [];
  if (ttsRange == null) return [TextSpan(text: text, style: baseStyle)];

  final segStart = textOffset;
  final segEnd = textOffset + text.length;

  // No overlap
  if (segEnd <= ttsRange.start || segStart >= ttsRange.end) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final ttsStyle = baseStyle?.copyWith(backgroundColor: _ttsHighlightColor) ??
      TextStyle(backgroundColor: _ttsHighlightColor);
  final spans = <TextSpan>[];

  final highlightStart = (ttsRange.start - segStart).clamp(0, text.length);
  final highlightEnd = (ttsRange.end - segStart).clamp(0, text.length);

  if (highlightStart > 0) {
    spans.add(TextSpan(text: text.substring(0, highlightStart), style: baseStyle));
  }
  spans.add(TextSpan(
      text: text.substring(highlightStart, highlightEnd), style: ttsStyle));
  if (highlightEnd < text.length) {
    spans.add(TextSpan(text: text.substring(highlightEnd), style: baseStyle));
  }

  return spans;
}
