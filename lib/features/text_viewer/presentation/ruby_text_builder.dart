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

TextSpan buildRubyTextSpans(
  List<TextSegment> segments,
  TextStyle? baseStyle,
  String? query,
) {
  if (segments.isEmpty) {
    return const TextSpan();
  }

  final hasQuery = query != null && query.isNotEmpty;
  final spans = <InlineSpan>[];

  for (final segment in segments) {
    switch (segment) {
      case PlainTextSegment(:final text):
        if (hasQuery) {
          spans.addAll(_buildHighlightedPlainSpans(text, query, baseStyle));
        } else {
          spans.add(TextSpan(text: text, style: baseStyle));
        }
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
    }
  }

  return TextSpan(children: spans);
}

List<TextSpan> _buildHighlightedPlainSpans(
  String text,
  String query,
  TextStyle? baseStyle,
) {
  final queryLower = query.toLowerCase();
  final textLower = text.toLowerCase();
  final highlightStyle = baseStyle?.copyWith(backgroundColor: Colors.yellow) ??
      const TextStyle(backgroundColor: Color(0xFFFFFF00));
  final spans = <TextSpan>[];
  var start = 0;

  var index = textLower.indexOf(queryLower, start);
  while (index != -1) {
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
    }
    spans.add(TextSpan(
      text: text.substring(index, index + query.length),
      style: highlightStyle,
    ));
    start = index + query.length;
    index = textLower.indexOf(queryLower, start);
  }

  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: baseStyle));
  } else if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: baseStyle));
  }

  return spans;
}
