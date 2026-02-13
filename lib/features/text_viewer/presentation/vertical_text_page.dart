import 'package:flutter/material.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_char_map.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_ruby_text_widget.dart';

class VerticalTextPage extends StatelessWidget {
  const VerticalTextPage({
    super.key,
    required this.segments,
    required this.baseStyle,
    this.query,
    this.selectionStart,
    this.selectionEnd,
  });

  final List<TextSegment> segments;
  final TextStyle? baseStyle;
  final String? query;
  final int? selectionStart;
  final int? selectionEnd;

  @override
  Widget build(BuildContext context) {
    final children = _buildCharacterWidgets();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        direction: Axis.vertical,
        spacing: 0.0,
        runSpacing: 4.0,
        children: children,
      ),
    );
  }

  List<Widget> _buildCharacterWidgets() {
    final charEntries = _buildCharEntries();
    final highlights = (query?.isNotEmpty ?? false)
        ? _computeHighlights(charEntries, query!)
        : const <int>{};

    return [
      for (var i = 0; i < charEntries.length; i++)
        _buildCharWidget(
          charEntries[i],
          isHighlighted: highlights.contains(i),
          isSelected: _isInSelection(i),
        ),
    ];
  }

  bool _isInSelection(int index) {
    final start = selectionStart;
    final end = selectionEnd;
    if (start == null || end == null) return false;
    return index >= start && index < end;
  }

  List<_CharEntry> _buildCharEntries() {
    final entries = <_CharEntry>[];
    for (final segment in segments) {
      switch (segment) {
        case PlainTextSegment(:final text):
          _addPlainTextEntries(entries, text);
        case RubyTextSegment(:final base, :final rubyText):
          entries.add(_CharEntry.ruby(base, rubyText));
      }
    }
    return entries;
  }

  Widget _buildCharWidget(
    _CharEntry entry, {
    required bool isHighlighted,
    required bool isSelected,
  }) {
    if (entry.isNewline) {
      return const SizedBox(width: 0, height: double.infinity);
    }

    if (entry.isRuby) {
      return VerticalRubyTextWidget(
        base: entry.text,
        rubyText: entry.rubyText!,
        baseStyle: baseStyle,
        highlighted: isHighlighted,
        selected: isSelected,
      );
    }

    return Text(
      mapToVerticalChar(entry.text),
      style: _createTextStyle(
        isHighlighted: isHighlighted,
        isSelected: isSelected,
      ),
    );
  }

  TextStyle _createTextStyle({
    required bool isHighlighted,
    required bool isSelected,
  }) {
    // Search highlight (yellow) takes precedence over selection (blue)
    final Color? backgroundColor;
    if (isHighlighted) {
      backgroundColor = Colors.yellow;
    } else if (isSelected) {
      backgroundColor = Colors.blue.withOpacity(0.3);
    } else {
      backgroundColor = null;
    }
    return baseStyle?.copyWith(backgroundColor: backgroundColor, height: 1.1) ??
        TextStyle(backgroundColor: backgroundColor, height: 1.1);
  }

  void _addPlainTextEntries(List<_CharEntry> entries, String text) {
    final runes = text.runes.toList();
    for (final rune in runes) {
      final char = String.fromCharCode(rune);
      if (char == '\n') {
        entries.add(_CharEntry.newline());
      } else {
        entries.add(_CharEntry.plain(char));
      }
    }
  }

  Set<int> _computeHighlights(List<_CharEntry> entries, String query) {
    final queryLower = query.toLowerCase();
    final indexMap = <int, int>{}; // buffer position -> entry index
    final buffer = StringBuffer();

    // Build searchable text with index mapping
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.isNewline) continue;

      final startPos = buffer.length;
      buffer.write(entry.text);
      for (var j = 0; j < entry.text.length; j++) {
        indexMap[startPos + j] = i;
      }
    }

    // Find all matches and collect highlighted indices
    final highlights = <int>{};
    final searchText = buffer.toString().toLowerCase();

    for (var pos = searchText.indexOf(queryLower);
        pos != -1;
        pos = searchText.indexOf(queryLower, pos + 1)) {
      for (var j = pos; j < pos + queryLower.length; j++) {
        final entryIndex = indexMap[j];
        if (entryIndex != null) highlights.add(entryIndex);
      }
    }

    return highlights;
  }
}

class _CharEntry {
  final String text;
  final String? rubyText;
  final bool isNewline;
  final bool isRuby;

  _CharEntry.plain(this.text)
      : rubyText = null,
        isNewline = false,
        isRuby = false;

  _CharEntry.newline()
      : text = '\n',
        rubyText = null,
        isNewline = true,
        isRuby = false;

  _CharEntry.ruby(this.text, this.rubyText)
      : isNewline = false,
        isRuby = true;
}
