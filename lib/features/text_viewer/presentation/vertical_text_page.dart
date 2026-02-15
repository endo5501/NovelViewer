import 'package:flutter/material.dart';
import 'package:novel_viewer/features/text_viewer/data/swipe_detection.dart';
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
    this.onSwipe,
  });

  final List<TextSegment> segments;
  final TextStyle? baseStyle;
  final String? query;
  final int? selectionStart;
  final int? selectionEnd;
  final ValueChanged<String?>? onSelectionChanged;
  final ValueChanged<SwipeDirection>? onSwipe;

  @override
  State<VerticalTextPage> createState() => _VerticalTextPageState();
}

// Effective visual gap between columns is 2 * _kRunSpacing due to sentinel
// SizedBoxes in the Wrap creating an extra run between each column pair.
const _kRunSpacing = 2.0;
const _kTextHeight = 1.1;
const _kDefaultFontSize = 14.0;

/// Gesture mode for distinguishing between text selection and page swiping.
enum _GestureMode { undecided, selecting, swiping }

/// Minimum displacement in pixels before the gesture mode is decided.
const _kGestureDecisionThreshold = 10.0;

class _VerticalTextPageState extends State<VerticalTextPage> {
  int? _anchorIndex;
  int? _selectionStart;
  int? _selectionEnd;

  // Swipe tracking
  Offset? _panStartGlobalPosition;
  Offset? _panLastGlobalPosition;
  _GestureMode _gestureMode = _GestureMode.undecided;

  late List<VerticalCharEntry> _charEntries;
  late List<List<int>> _columns;
  final Map<int, GlobalKey> _entryKeys = {};
  List<VerticalHitRegion> _hitRegions = const [];
  bool _hitRegionUpdateScheduled = false;

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
      return;
    }
    if (oldWidget.baseStyle != widget.baseStyle) {
      _scheduleHitRegionRebuild();
    }
  }

  void _rebuildEntries() {
    _charEntries = buildVerticalCharEntries(widget.segments);
    _columns = buildColumnStructure(_charEntries);
    _entryKeys.clear();
    for (final column in _columns) {
      for (final index in column) {
        _entryKeys[index] = GlobalKey(debugLabel: 'vertical_char_$index');
      }
    }
    _hitRegions = const [];
    _scheduleHitRegionRebuild();
  }

  int? get _effectiveStart => widget.selectionStart ?? _selectionStart;
  int? get _effectiveEnd => widget.selectionEnd ?? _selectionEnd;

  @override
  Widget build(BuildContext context) {
    final highlights = (widget.query?.isNotEmpty ?? false)
        ? _computeHighlights(widget.query!)
        : const <int>{};

    final children = <Widget>[];
    for (var i = 0; i < _charEntries.length; i++) {
      final entry = _charEntries[i];
      final child = _buildCharWidget(
        entry,
        isHighlighted: highlights.contains(i),
        isSelected: _isInSelection(i),
      );
      if (entry.isNewline) {
        children.add(child);
        continue;
      }
      final key = _entryKeys[i];
      if (key == null) {
        children.add(child);
        continue;
      }
      children.add(KeyedSubtree(key: key, child: child));
    }
    _scheduleHitRegionRebuild();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: _onPanDown,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
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
  }

  bool _isInSelection(int index) {
    final start = _effectiveStart;
    final end = _effectiveEnd;
    if (start == null || end == null) return false;
    return index >= start && index < end;
  }

  void _onPanDown(DragDownDetails details) {
    _panStartGlobalPosition = details.globalPosition;
    _panLastGlobalPosition = details.globalPosition;
    _gestureMode = _GestureMode.undecided;
  }

  void _onPanStart(DragStartDetails details) {
    _anchorIndex = _hitTest(details.localPosition);
    _tryDecideGestureMode(details.globalPosition);
  }

  /// Attempts to decide the gesture mode based on displacement from start.
  /// Returns true if the mode was decided, false if still undecided.
  bool _tryDecideGestureMode(Offset currentPosition) {
    final startPos = _panStartGlobalPosition;
    if (startPos == null) return false;

    final displacement = currentPosition - startPos;
    if (displacement.distance < _kGestureDecisionThreshold) return false;

    final isHorizontalDominant = displacement.dx.abs() > displacement.dy.abs();
    _gestureMode = isHorizontalDominant
        ? _GestureMode.swiping
        : _GestureMode.selecting;

    if (_gestureMode == _GestureMode.selecting) {
      _startSelection();
    }
    return true;
  }

  /// Initializes selection state when entering selecting mode.
  void _startSelection() {
    final anchor = _anchorIndex;
    if (anchor == null) return;

    setState(() {
      _selectionStart = anchor;
      _selectionEnd = anchor + 1;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _panLastGlobalPosition = details.globalPosition;

    switch (_gestureMode) {
      case _GestureMode.undecided:
        _handleUndecidedUpdate(details);
      case _GestureMode.selecting:
        _handleSelectingUpdate(details);
      case _GestureMode.swiping:
        break;
    }
  }

  void _handleUndecidedUpdate(DragUpdateDetails details) {
    if (_tryDecideGestureMode(details.globalPosition) &&
        _gestureMode == _GestureMode.selecting) {
      _handleSelectingUpdate(details);
    }
  }

  void _handleSelectingUpdate(DragUpdateDetails details) {
    final index = _hitTest(details.localPosition, snapToNearest: true);
    final anchor = _anchorIndex;
    if (index == null || anchor == null) return;

    final (start, end) = index >= anchor
        ? (anchor, index + 1)
        : (index, anchor + 1);

    setState(() {
      _selectionStart = start;
      _selectionEnd = end;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    switch (_gestureMode) {
      case _GestureMode.swiping:
      case _GestureMode.undecided:
        _handleSwipeEnd(details);
      case _GestureMode.selecting:
        _notifySelectionChanged();
    }
    _gestureMode = _GestureMode.undecided;
  }

  void _handleSwipeEnd(DragEndDetails details) {
    final startPos = _panStartGlobalPosition;
    final endPos = details.globalPosition != Offset.zero
        ? details.globalPosition
        : _panLastGlobalPosition;

    final direction = (startPos != null && endPos != null)
        ? detectSwipeFromDrag(
            startPosition: startPos,
            endPosition: endPos,
            velocity: details.velocity,
          )
        : null;

    _clearInternalSelection();
    if (direction != null) {
      widget.onSwipe?.call(direction);
    }
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

  int? _hitTest(Offset localPosition, {bool snapToNearest = false}) {
    if (_hitRegions.isEmpty) {
      _rebuildHitRegions();
    }
    return hitTestCharIndexFromRegions(
      localPosition: localPosition,
      hitRegions: _hitRegions,
      snapToNearest: snapToNearest,
    );
  }

  void _scheduleHitRegionRebuild() {
    if (_hitRegionUpdateScheduled) return;
    _hitRegionUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hitRegionUpdateScheduled = false;
      if (!mounted) return;
      _rebuildHitRegions();
    });
  }

  void _rebuildHitRegions() {
    final pageRenderObject = context.findRenderObject();
    if (pageRenderObject is! RenderBox || !pageRenderObject.hasSize) return;

    final regions = <VerticalHitRegion>[];
    for (final column in _columns) {
      for (final index in column) {
        final renderObject = _entryKeys[index]?.currentContext?.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.hasSize) continue;
        final topLeft = renderObject.localToGlobal(
          Offset.zero,
          ancestor: pageRenderObject,
        );
        var rect = topLeft & renderObject.size;
        if (_charEntries[index].isRuby) {
          final rubyFontSize =
              (widget.baseStyle?.fontSize ?? _kDefaultFontSize) * 0.5;
          rect = Rect.fromLTRB(
            rect.left,
            rect.top,
            rect.right + rubyFontSize + 2,
            rect.bottom,
          );
        }
        regions.add(
          VerticalHitRegion(
            charIndex: index,
            rect: rect,
          ),
        );
      }
    }

    _hitRegions = regions;
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
    final backgroundColor = isHighlighted
        ? Colors.yellow
        : isSelected
            ? Colors.blue.withValues(alpha: 0.3)
            : null;

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
