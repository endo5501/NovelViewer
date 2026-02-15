import 'package:flutter/material.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_char_map.dart';

class VerticalRubyTextWidget extends StatelessWidget {
  const VerticalRubyTextWidget({
    super.key,
    required this.base,
    required this.rubyText,
    required this.baseStyle,
    this.highlighted = false,
    this.selected = false,
  });

  final String base;
  final String rubyText;
  final TextStyle? baseStyle;
  final bool highlighted;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final fontSize = baseStyle?.fontSize ?? 14.0;
    final rubyFontSize = fontSize * 0.5;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildBaseText(_toVerticalChars(base), fontSize),
        _buildRubyText(_toVerticalChars(rubyText), rubyFontSize),
      ],
    );
  }

  List<String> _toVerticalChars(String text) {
    return text.runes
        .map((r) => mapToVerticalChar(String.fromCharCode(r)))
        .toList();
  }

  Widget _buildBaseText(List<String> baseChars, double charWidth) {
    // Search highlight (yellow) takes precedence over selection (blue)
    final bgColor = highlighted
        ? Colors.yellow
        : selected
            ? Colors.blue.withValues(alpha: 0.3)
            : null;

    final style = _createTextStyle(
      fontSize: baseStyle?.fontSize,
      backgroundColor: bgColor,
    );

    return _buildVerticalText(baseChars, style, charWidth);
  }

  Widget _buildRubyText(List<String> rubyChars, double rubyFontSize) {
    final style = _createTextStyle(fontSize: rubyFontSize);

    return Positioned(
      right: -(rubyFontSize + 2),
      top: 0,
      child: _buildVerticalText(rubyChars, style, rubyFontSize),
    );
  }

  Widget _buildVerticalText(
      List<String> chars, TextStyle? style, double charWidth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final char in chars)
          SizedBox(
            width: charWidth,
            child: Text(char, textAlign: TextAlign.center, style: style),
          ),
      ],
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
