import 'package:flutter/material.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_char_map.dart';

class VerticalRubyTextWidget extends StatelessWidget {
  const VerticalRubyTextWidget({
    super.key,
    required this.base,
    required this.rubyText,
    required this.baseStyle,
    this.highlighted = false,
  });

  final String base;
  final String rubyText;
  final TextStyle? baseStyle;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fontSize = baseStyle?.fontSize ?? 14.0;
    final backgroundColor = highlighted ? Colors.yellow : null;

    final baseChars = base.runes
        .map((r) => mapToVerticalChar(String.fromCharCode(r)))
        .toList();
    final rubyChars = rubyText.runes
        .map((r) => String.fromCharCode(r))
        .toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ruby text (right side in RTL context)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final char in rubyChars)
              Text(
                char,
                style: baseStyle?.copyWith(
                  fontSize: fontSize * 0.5,
                  height: 1.0,
                ),
              ),
          ],
        ),
        // Base text
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final char in baseChars)
              Text(
                char,
                style: baseStyle?.copyWith(
                  height: 1.0,
                  backgroundColor: backgroundColor,
                ) ?? TextStyle(height: 1.0, backgroundColor: backgroundColor),
              ),
          ],
        ),
      ],
    );
  }
}
