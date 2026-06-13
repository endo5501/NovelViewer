import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:novel_viewer/features/llm_summary/domain/hover_token.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/swipe_detection.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_char_map.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_marked_ranges.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_text_layout.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_ruby_text_widget.dart';

export 'package:novel_viewer/features/llm_summary/domain/hover_token.dart'
    show HoverToken;

/// Test-only: increments each time [_VerticalTextPageState] actually computes
/// the TTS highlight set (a cache miss). F116 memoizes it so rebuilds that do
/// not change the TTS range / entries / page offset reuse the cached set.
@visibleForTesting
int verticalTtsHighlightComputeCount = 0;

/// Test-only: increments each time a post-frame hit-region rebuild is newly
/// scheduled. F116 schedules it only when a layout-affecting input (entries,
/// style, column spacing) changes — not on selection or TTS rebuilds.
@visibleForTesting
int verticalHitRegionScheduleCount = 0;

class VerticalTextPage extends StatefulWidget {
  const VerticalTextPage({
    super.key,
    required this.segments,
    required this.baseStyle,
    this.query,
    this.selectionStart,
    this.selectionEnd,
    this.ttsHighlightStart,
    this.ttsHighlightEnd,
    this.pageStartTextOffset = 0,
    this.lineBreakEntryIndices,
    this.onSelectionChanged,
    this.onSwipe,
    this.onContextMenu,
    this.columnSpacing = 8.0,
    this.markedWords = const {},
    this.onMarkEnter,
    this.onMarkExit,
    this.onHoverHideRequest,
  }) : assert(columnSpacing >= 0);

  final List<TextSegment> segments;
  final TextStyle? baseStyle;
  final String? query;
  final int? selectionStart;
  final int? selectionEnd;
  final int? ttsHighlightStart;
  final int? ttsHighlightEnd;
  final int pageStartTextOffset;

  /// Indices of the newline entries that correspond to real paragraph breaks.
  /// Newline entries not in this set are visual column-wrap breaks. When null,
  /// every newline is treated as a real break (legacy behaviour).
  final Set<int>? lineBreakEntryIndices;
  final ValueChanged<String?>? onSelectionChanged;
  final ValueChanged<SwipeDirection>? onSwipe;
  final void Function(Offset position, String selectedText)? onContextMenu;
  final double columnSpacing;
  final Map<String, MarkStyle> markedWords;
  final void Function(String word, Offset globalPosition, HoverToken token)?
      onMarkEnter;
  final void Function(HoverToken token)? onMarkExit;

  /// Coarse "drop any active popup" signal — fired when the page's overall
  /// hover state can no longer be trusted (selection drag starts here, page
  /// turn requested by the parent viewer). Distinct from [onMarkExit], which
  /// only carries the most recently entered token.
  final VoidCallback? onHoverHideRequest;

  @override
  State<VerticalTextPage> createState() => _VerticalTextPageState();
}

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
  Set<int> _emptyColumnNewlines = const {};
  final Map<int, GlobalKey> _entryKeys = {};
  List<VerticalHitRegion> _hitRegions = const [];
  bool _hitRegionUpdateScheduled = false;

  // Hover differential state — kept in sync as the pointer moves so
  // adjacent hover events inside one mark coalesce into a single
  // onMarkEnter and crossings into/out of marks fire exit/enter exactly
  // once per transition.
  int? _lastHoverCharIndex;
  HoverToken? _lastHoverToken;
  Map<int, MarkInfo> _markedRanges = const {};

  // F116: memoization keys for the per-build mark map. Recompute only when the
  // entries, the marked words, or the line-break indices change — not on
  // selection / TTS / search rebuilds.
  List<VerticalCharEntry>? _markedRangesEntries;
  Map<String, MarkStyle>? _markedRangesWords;
  Set<int>? _markedRangesLineBreaks;

  // F116: memoization for the TTS highlight set. Its inputs are the TTS range,
  // the page text offset, the entries, and the line-break indices.
  Set<int> _ttsHighlights = const {};
  int? _ttsCacheStart;
  int? _ttsCacheEnd;
  int? _ttsCachePageOffset;
  List<VerticalCharEntry>? _ttsCacheEntries;
  Set<int>? _ttsCacheLineBreaks;

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
      // Entry indices change meaning when segments rebuild, so any stale
      // hover state would otherwise suppress the next onMarkEnter via the
      // _lastHoverCharIndex differential check.
      _lastHoverCharIndex = null;
      _lastHoverToken = null;
      return;
    }
    // Character rectangles move when the font style or the column spacing
    // changes, so the hit regions must be rebuilt in those cases. (Segments
    // changes are handled by the early-return _rebuildEntries path above.)
    if (oldWidget.baseStyle != widget.baseStyle ||
        oldWidget.columnSpacing != widget.columnSpacing) {
      _scheduleHitRegionRebuild();
    }
  }

  void _rebuildEntries() {
    _charEntries = buildVerticalCharEntries(widget.segments);
    _columns = buildColumnStructure(_charEntries);
    _emptyColumnNewlines = _computeEmptyColumnNewlines();
    _entryKeys.clear();
    for (final column in _columns) {
      for (final index in column) {
        _entryKeys[index] = GlobalKey(debugLabel: 'vertical_char_$index');
      }
    }
    _hitRegions = const [];
    _scheduleHitRegionRebuild();
  }

  /// Identifies newline entry indices that start empty columns (blank lines).
  Set<int> _computeEmptyColumnNewlines() {
    final result = <int>{};
    var columnIndex = 0;
    for (var i = 0; i < _charEntries.length; i++) {
      if (_charEntries[i].isNewline) {
        columnIndex++;
        if (columnIndex < _columns.length && _columns[columnIndex].isEmpty) {
          result.add(i);
        }
      }
    }
    return result;
  }

  int? get _effectiveStart => widget.selectionStart ?? _selectionStart;
  int? get _effectiveEnd => widget.selectionEnd ?? _selectionEnd;

  @override
  Widget build(BuildContext context) {
    final highlights = (widget.query?.isNotEmpty ?? false)
        ? _computeHighlights(widget.query!)
        : const <int>{};
    final ttsHighlights = _memoizedTtsHighlights();
    _markedRanges = _memoizedMarkedRanges();

    final fontSize = widget.baseStyle?.fontSize ?? _kDefaultFontSize;
    final children = <Widget>[];

    // Leading empty column has no preceding newline, so add an explicit spacer
    if (_columns.isNotEmpty && _columns.first.isEmpty) {
      children.add(SizedBox(width: fontSize, height: double.infinity));
    }

    for (var i = 0; i < _charEntries.length; i++) {
      final entry = _charEntries[i];
      if (entry.isNewline) {
        final width = _emptyColumnNewlines.contains(i) ? fontSize : 0.0;
        children.add(SizedBox(width: width, height: double.infinity));
        continue;
      }
      final child = _buildCharWidget(
        entry,
        isHighlighted: highlights.contains(i),
        isSelected: _isInSelection(i),
        isTtsHighlighted: ttsHighlights.contains(i),
        markStyle: _markedRanges[i]?.style,
      );
      final key = _entryKeys[i];
      if (key == null) {
        children.add(child);
        continue;
      }
      children.add(KeyedSubtree(key: key, child: child));
    }
    // F116: the hit-region rebuild is NOT scheduled here. Character rectangles
    // only move when the entries/columns (segments), the text style, or the
    // column spacing change — all handled by _rebuildEntries / didUpdateWidget.
    // Selection and TTS rebuilds reach this point without moving any rect.

    return MouseRegion(
      onHover: _onHover,
      onExit: _onMouseExit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: _onPanDown,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTap: _onTap,
        onSecondaryTapUp: _onSecondaryTapUp,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            direction: Axis.vertical,
            spacing: 0.0,
            runSpacing: widget.columnSpacing,
            children: children,
          ),
        ),
      ),
    );
  }

  void _onHover(PointerHoverEvent event) {
    final charIndex = _hitTest(event.localPosition);
    final newMark = charIndex == null ? null : _markedRanges[charIndex];
    final newToken = newMark == null
        ? null
        : (start: newMark.startEntry, end: newMark.endEntry);

    // Coalesce on the TOKEN value (not charIndex alone). This way a
    // markedWords change that removes/replaces the mark under a stationary
    // pointer still fires the appropriate exit/enter because newToken
    // differs from _lastHoverToken even though the pixel and charIndex
    // are unchanged.
    if (charIndex == _lastHoverCharIndex && newToken == _lastHoverToken) {
      return;
    }

    if (newToken != _lastHoverToken) {
      if (_lastHoverToken != null) {
        widget.onMarkExit?.call(_lastHoverToken!);
      }
      if (newMark != null) {
        widget.onMarkEnter?.call(newMark.word, event.position, newToken!);
      }
    }

    _lastHoverCharIndex = charIndex;
    _lastHoverToken = newToken;
  }

  void _onMouseExit(PointerExitEvent _) {
    if (_lastHoverToken != null) {
      widget.onMarkExit?.call(_lastHoverToken!);
    }
    _lastHoverCharIndex = null;
    _lastHoverToken = null;
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
    // A real drag (not a tap) just began. onHover stops firing while a
    // button is held, so any popup already visible would otherwise linger.
    // Also clear the local hover diff so the popup can re-appear on the
    // same charIndex after the drag ends.
    _requestHoverHide();
    _tryDecideGestureMode(details.globalPosition);
  }

  void _requestHoverHide() {
    _lastHoverCharIndex = null;
    _lastHoverToken = null;
    widget.onHoverHideRequest?.call();
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

  void _onSecondaryTapUp(TapUpDetails details) {
    final start = _effectiveStart;
    final end = _effectiveEnd;
    if (start == null || end == null || start >= end) return;
    final text = extractVerticalSelectedText(
      _charEntries,
      start,
      end,
      lineBreakEntryIndices: widget.lineBreakEntryIndices,
    );
    if (text.isEmpty) return;
    widget.onContextMenu?.call(details.globalPosition, text);
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
    final text = extractVerticalSelectedText(
      _charEntries,
      start,
      end,
      lineBreakEntryIndices: widget.lineBreakEntryIndices,
    );
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
    verticalHitRegionScheduleCount++;
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
    bool isTtsHighlighted = false,
    MarkStyle? markStyle,
  }) {
    final Widget core;
    if (entry.isRuby) {
      core = VerticalRubyTextWidget(
        base: entry.text,
        rubyText: entry.rubyText!,
        baseStyle: widget.baseStyle,
        highlighted: isHighlighted,
        selected: isSelected,
      );
    } else {
      final fontSize = widget.baseStyle?.fontSize ?? _kDefaultFontSize;
      final style = _createTextStyle(
        isHighlighted: isHighlighted,
        isSelected: isSelected,
        isTtsHighlighted: isTtsHighlighted,
      );
      // Rotation-target punctuation (quotes/apostrophes/backticks/colons/
      // semicolons) has no usable vertical presentation form, so it is
      // physically rotated 90° clockwise instead of being substituted.
      // Transform.rotate is a paint-only transform: it keeps the cell's
      // layout dimensions identical to a normal character cell, preserving
      // the vertical column rhythm (RotatedBox would shrink the cell height).
      final Widget inner = shouldRotateVertical(entry.text)
          ? Transform.rotate(
              angle: math.pi / 2,
              child: Text(
                entry.text,
                textAlign: TextAlign.center,
                style: style,
              ),
            )
          : Text(
              mapToVerticalChar(entry.text),
              textAlign: TextAlign.center,
              style: style,
            );
      core = SizedBox(
        width: fontSize,
        child: inner,
      );
    }
    if (markStyle == null) return core;
    return CustomPaint(
      foregroundPainter: _VerticalMarkSidebarPainter(
        style: markStyle,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      child: core,
    );
  }

  TextStyle _createTextStyle({
    required bool isHighlighted,
    required bool isSelected,
    bool isTtsHighlighted = false,
  }) {
    // Priority: search highlight (yellow/amber) > TTS highlight (green) > selection (blue)
    final brightness = Theme.of(context).brightness;
    final Color? backgroundColor;
    final Color? foregroundColor;
    if (isHighlighted) {
      backgroundColor = searchHighlightBackground(brightness);
      foregroundColor = searchHighlightForeground(brightness);
    } else if (isTtsHighlighted) {
      backgroundColor = Colors.green.withValues(alpha: 0.3);
      foregroundColor = null;
    } else if (isSelected) {
      backgroundColor = Colors.blue.withValues(alpha: 0.3);
      foregroundColor = null;
    } else {
      backgroundColor = null;
      foregroundColor = null;
    }

    return widget.baseStyle
            ?.copyWith(
                backgroundColor: backgroundColor,
                color: foregroundColor,
                height: _kTextHeight) ??
        TextStyle(
            backgroundColor: backgroundColor,
            color: foregroundColor,
            height: _kTextHeight);
  }

  /// Returns the mark map, recomputing only when the entries, marked words, or
  /// line-break indices change. Entries and marked words are compared by
  /// identity (both are rebuilt as fresh instances when their content changes).
  Map<int, MarkInfo> _memoizedMarkedRanges() {
    if (identical(_markedRangesEntries, _charEntries) &&
        identical(_markedRangesWords, widget.markedWords) &&
        _markedRangesLineBreaks == widget.lineBreakEntryIndices) {
      return _markedRanges;
    }
    final result = computeMarkedRanges(
      entries: _charEntries,
      markedWords: widget.markedWords,
      lineBreakEntryIndices: widget.lineBreakEntryIndices,
    );
    _markedRangesEntries = _charEntries;
    _markedRangesWords = widget.markedWords;
    _markedRangesLineBreaks = widget.lineBreakEntryIndices;
    return result;
  }

  /// Returns the TTS highlight set, recomputing only when the TTS range, the
  /// page text offset, the entries, or the line-break indices change.
  Set<int> _memoizedTtsHighlights() {
    if (identical(_ttsCacheEntries, _charEntries) &&
        _ttsCacheStart == widget.ttsHighlightStart &&
        _ttsCacheEnd == widget.ttsHighlightEnd &&
        _ttsCachePageOffset == widget.pageStartTextOffset &&
        _ttsCacheLineBreaks == widget.lineBreakEntryIndices) {
      return _ttsHighlights;
    }
    _ttsHighlights = _computeTtsHighlights();
    _ttsCacheEntries = _charEntries;
    _ttsCacheStart = widget.ttsHighlightStart;
    _ttsCacheEnd = widget.ttsHighlightEnd;
    _ttsCachePageOffset = widget.pageStartTextOffset;
    _ttsCacheLineBreaks = widget.lineBreakEntryIndices;
    return _ttsHighlights;
  }

  Set<int> _computeTtsHighlights() {
    verticalTtsHighlightComputeCount++;
    final globalStart = widget.ttsHighlightStart;
    final globalEnd = widget.ttsHighlightEnd;
    if (globalStart == null || globalEnd == null) return const {};

    // Convert global TTS range to page-local range
    final pageOffset = widget.pageStartTextOffset;
    final localStart = globalStart - pageOffset;
    final localEnd = globalEnd - pageOffset;

    final result = <int>{};
    var plainTextOffset = 0;

    for (var i = 0; i < _charEntries.length; i++) {
      final entry = _charEntries[i];
      if (entry.isNewline) {
        // Line-break newlines count as 1 char in the original text offset
        if (widget.lineBreakEntryIndices?.contains(i) ?? false) {
          plainTextOffset += 1;
        }
        continue;
      }

      final charEnd = plainTextOffset + entry.text.length;

      if (charEnd > localStart && plainTextOffset < localEnd) {
        result.add(i);
      }
      plainTextOffset = charEnd;
    }

    return result;
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

/// Draws a thin sidebar line to the LEFT of a vertically-rendered character
/// to indicate it falls inside an LLM-summary research mark.
class _VerticalMarkSidebarPainter extends CustomPainter {
  final MarkStyle style;
  final Color color;

  _VerticalMarkSidebarPainter({required this.style, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const x = 1.0;
    switch (style) {
      case MarkStyle.solid:
        canvas.drawLine(const Offset(x, 0), Offset(x, size.height), paint);
        break;
      case MarkStyle.dotted:
        const dashLength = 2.0;
        const gapLength = 2.0;
        var y = 0.0;
        while (y < size.height) {
          canvas.drawLine(
            Offset(x, y),
            Offset(x, (y + dashLength).clamp(0, size.height)),
            paint,
          );
          y += dashLength + gapLength;
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_VerticalMarkSidebarPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.color != color;
}
