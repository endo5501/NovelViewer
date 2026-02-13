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
    final rubyFontSize = fontSize * 0.5;

    final baseChars = base.runes
        .map((r) => mapToVerticalChar(String.fromCharCode(r)))
        .toList();
    final rubyChars =
        rubyText.runes.map((r) => String.fromCharCode(r)).toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildBaseText(baseChars),
        _buildRubyText(rubyChars, rubyFontSize),
      ],
    );
  }

  Widget _buildBaseText(List<String> baseChars) {
    final style = _createTextStyle(
      fontSize: baseStyle?.fontSize,
      backgroundColor: highlighted ? Colors.yellow : null,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final char in baseChars) Text(char, style: style),
      ],
    );
  }

  Widget _buildRubyText(List<String> rubyChars, double rubyFontSize) {
    final style = _createTextStyle(fontSize: rubyFontSize);

    return Positioned(
      right: -(rubyFontSize + 2),
      top: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final char in rubyChars) Text(char, style: style),
        ],
      ),
    );
  }

  TextStyle _createTextStyle({
    double? fontSize,
    Color? backgroundColor,
  }) {
    return baseStyle?.copyWith(
          fontSize: fontSize,
          height: 1.1,
          backgroundColor: backgroundColor,
        ) ??
        TextStyle(
          fontSize: fontSize,
          height: 1.1,
          backgroundColor: backgroundColor,
        );
  }
}
