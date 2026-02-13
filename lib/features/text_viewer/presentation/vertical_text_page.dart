import 'package:flutter/material.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_char_map.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_text_layout.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_ruby_text_widget.dart';

class VerticalTextPage extends StatefulWidget {
  const VerticalTextPage({
    super.key,
    required this.segments,
    required this.baseStyle,
    this.query,
    this.selectionStart,
    this.selectionEnd,
    this.onSelectionChanged,
  });

  final List<TextSegment> segments;
  final TextStyle? baseStyle;
  final String? query;
  final int? selectionStart;
  final int? selectionEnd;
  final ValueChanged<String?>? onSelectionChanged;

  @override
  State<VerticalTextPage> createState() => _VerticalTextPageState();
}

const _kRunSpacing = 4.0;
const _kTextHeight = 1.1;
const _kDefaultFontSize = 14.0;

class _VerticalTextPageState extends State<VerticalTextPage> {
  int? _anchorIndex;
  int? _selectionStart;
  int? _selectionEnd;

  late List<VerticalCharEntry> _charEntries;
  late List<List<int>> _columns;

  @override
  void initState() {
    super.initState();
    _rebuildEntries();
  }

  @override
  void didUpdateWidget(VerticalTextPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments) {
      _rebuildEntries();
      _clearInternalSelection();
    }
  }

  void _rebuildEntries() {
    _charEntries = buildVerticalCharEntries(widget.segments);
    _columns = buildColumnStructure(_charEntries);
  }

  int? get _effectiveStart => widget.selectionStart ?? _selectionStart;
  int? get _effectiveEnd => widget.selectionEnd ?? _selectionEnd;

  @override
  Widget build(BuildContext context) {
    final highlights = (widget.query?.isNotEmpty ?? false)
        ? _computeHighlights(widget.query!)
        : const <int>{};

    final children = [
      for (var i = 0; i < _charEntries.length; i++)
        _buildCharWidget(
          _charEntries[i],
          isHighlighted: highlights.contains(i),
          isSelected: _isInSelection(i),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) =>
              _onPanStart(details, constraints.maxWidth),
          onPanUpdate: (details) =>
              _onPanUpdate(details, constraints.maxWidth),
          onPanEnd: _onPanEnd,
          onTap: _onTap,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              direction: Axis.vertical,
              spacing: 0.0,
              runSpacing: _kRunSpacing,
              children: children,
            ),
          ),
        );
      },
    );
  }

  bool _isInSelection(int index) {
    final start = _effectiveStart;
    final end = _effectiveEnd;
    if (start == null || end == null) return false;
    return index >= start && index < end;
  }

  void _onPanStart(DragStartDetails details, double availableWidth) {
    final index = _hitTest(details.localPosition, availableWidth);
    if (index != null) {
      setState(() {
        _anchorIndex = index;
        _selectionStart = index;
        _selectionEnd = index + 1;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details, double availableWidth) {
    final index = _hitTest(details.localPosition, availableWidth);
    if (index != null && _anchorIndex != null) {
      final anchor = _anchorIndex!;
      setState(() {
        if (index >= anchor) {
          _selectionStart = anchor;
          _selectionEnd = index + 1;
        } else {
          _selectionStart = index;
          _selectionEnd = anchor + 1;
        }
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _notifySelectionChanged();
  }

  void _onTap() {
    _clearInternalSelection();
    widget.onSelectionChanged?.call(null);
  }

  void _clearInternalSelection() {
    setState(() {
      _anchorIndex = null;
      _selectionStart = null;
      _selectionEnd = null;
    });
  }

  void _notifySelectionChanged() {
    final start = _effectiveStart;
    final end = _effectiveEnd;
    if (start == null || end == null || start >= end) {
      widget.onSelectionChanged?.call(null);
      return;
    }
    final text = extractVerticalSelectedText(_charEntries, start, end);
    widget.onSelectionChanged?.call(text.isEmpty ? null : text);
  }

  int? _hitTest(Offset localPosition, double availableWidth) {
    return hitTestCharIndex(
      localPosition: localPosition,
      availableWidth: availableWidth,
      fontSize: widget.baseStyle?.fontSize ?? _kDefaultFontSize,
      runSpacing: _kRunSpacing,
      textHeight: _kTextHeight,
      columns: _columns,
    );
  }

  Widget _buildCharWidget(
    VerticalCharEntry entry, {
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
        baseStyle: widget.baseStyle,
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
    final Color? backgroundColor;
    if (isHighlighted) {
      backgroundColor = Colors.yellow;
    } else if (isSelected) {
      backgroundColor = Colors.blue.withOpacity(0.3);
    } else {
      backgroundColor = null;
    }
    return widget.baseStyle
            ?.copyWith(backgroundColor: backgroundColor, height: _kTextHeight) ??
        TextStyle(backgroundColor: backgroundColor, height: _kTextHeight);
  }

  Set<int> _computeHighlights(String query) {
    final queryLower = query.toLowerCase();
    final indexMap = <int, int>{};
    final buffer = StringBuffer();

    for (var i = 0; i < _charEntries.length; i++) {
      final entry = _charEntries[i];
      if (entry.isNewline) continue;

      final startPos = buffer.length;
      buffer.write(entry.text);
      for (var j = 0; j < entry.text.length; j++) {
        indexMap[startPos + j] = i;
      }
    }

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
