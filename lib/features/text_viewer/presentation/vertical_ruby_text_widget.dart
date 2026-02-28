import 'package:flutter/material.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_char_map.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';

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

    final brightness = Theme.of(context).brightness;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildBaseText(_toVerticalChars(base), fontSize, brightness),
        _buildRubyText(_toVerticalChars(rubyText), rubyFontSize),
      ],
    );
  }

  List<String> _toVerticalChars(String text) {
    return text.runes
        .map((r) => mapToVerticalChar(String.fromCharCode(r)))
        .toList();
  }

  Widget _buildBaseText(
      List<String> baseChars, double charWidth, Brightness brightness) {
    // Search highlight takes precedence over selection (blue)
    final Color? bgColor;
    final Color? fgColor;
    if (highlighted) {
      bgColor = searchHighlightBackground(brightness);
      fgColor = searchHighlightForeground(brightness);
    } else if (selected) {
      bgColor = Colors.blue.withValues(alpha: 0.3);
      fgColor = null;
    } else {
      bgColor = null;
      fgColor = null;
    }

    final style = _createTextStyle(
      fontSize: baseStyle?.fontSize,
      backgroundColor: bgColor,
      color: fgColor,
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
    Color? color,
  }) {
    return baseStyle?.copyWith(
          fontSize: fontSize,
          height: 1.1,
          backgroundColor: backgroundColor,
          color: color,
        ) ??
        TextStyle(
          fontSize: fontSize,
          height: 1.1,
          backgroundColor: backgroundColor,
          color: color,
        );
  }
}
