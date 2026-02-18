import 'dart:ui' show TextRange;

import 'package:flutter/material.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';

class RubyTextWidget extends StatelessWidget {
  const RubyTextWidget({
    super.key,
    required this.base,
    required this.rubyText,
    required this.baseStyle,
    this.query,
  });

  final String base;
  final String rubyText;
  final TextStyle? baseStyle;
  final String? query;

  @override
  Widget build(BuildContext context) {
    final fontSize = baseStyle?.fontSize ?? 14.0;
    final rubyFontSize = fontSize * 0.5;

    final baseWidget = (query != null && query!.isNotEmpty)
        ? Text.rich(
            TextSpan(
              children: _buildHighlightedPlainSpans(
                base,
                query!,
                baseStyle?.copyWith(height: 1.0),
              ),
            ),
          )
        : Text(base, style: baseStyle?.copyWith(height: 1.0));

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

TextSpan buildRubyTextSpans(
  List<TextSegment> segments,
  TextStyle? baseStyle,
  String? query, {
  TextRange? ttsHighlightRange,
}) {
  if (segments.isEmpty) {
    return const TextSpan();
  }

  final hasQuery = query != null && query.isNotEmpty;
  final hasTts = ttsHighlightRange != null;
  final spans = <InlineSpan>[];
  var plainTextOffset = 0;

  for (final segment in segments) {
    switch (segment) {
      case PlainTextSegment(:final text):
        if (hasQuery) {
          spans.addAll(_buildHighlightedPlainSpans(text, query, baseStyle,
              ttsRange: ttsHighlightRange, textOffset: plainTextOffset));
        } else if (hasTts) {
          spans.addAll(_buildTtsHighlightedSpans(
              text, baseStyle, ttsHighlightRange, plainTextOffset));
        } else {
          spans.add(TextSpan(text: text, style: baseStyle));
        }
        plainTextOffset += text.length;
      case RubyTextSegment(:final base, :final rubyText):
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: RubyTextWidget(
            base: base,
            rubyText: rubyText,
            baseStyle: baseStyle,
            query: hasQuery ? query : null,
          ),
        ));
        plainTextOffset += base.length;
    }
  }

  return TextSpan(style: baseStyle, children: spans);
}

List<TextSpan> _buildHighlightedPlainSpans(
  String text,
  String query,
  TextStyle? baseStyle, {
  TextRange? ttsRange,
  int textOffset = 0,
}) {
  final queryLower = query.toLowerCase();
  final textLower = text.toLowerCase();
  final searchHighlightStyle =
      baseStyle?.copyWith(backgroundColor: Colors.yellow) ??
          const TextStyle(backgroundColor: Color(0xFFFFFF00));
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
