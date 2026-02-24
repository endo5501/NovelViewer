import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novel_viewer/features/text_viewer/data/swipe_detection.dart';
import 'package:novel_viewer/features/text_viewer/data/column_splitter.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';

@visibleForTesting
List<int> computeCharOffsetPerPage(
  List<List<TextSegment>> columns,
  List<int> pageStarts,
  List<int> lineStartColumns,
) {
  final lineStartSet = lineStartColumns.skip(1).toSet();
  final cumulative = <int>[];
  var total = 0;
  for (var colIdx = 0; colIdx < columns.length; colIdx++) {
    // Count original newline before this column (if it starts a new line)
    if (lineStartSet.contains(colIdx)) {
      total += 1;
    }
    // Record offset at the start of this column
    cumulative.add(total);
    for (final seg in columns[colIdx]) {
      total += switch (seg) {
        PlainTextSegment(:final text) => text.length,
        RubyTextSegment(:final base) => base.length,
      };
    }
  }
  return pageStarts.map((start) => cumulative[start]).toList();
}

class VerticalTextViewer extends StatefulWidget {
  const VerticalTextViewer({
    super.key,
    required this.segments,
    required this.baseStyle,
    this.query,
    this.targetLineNumber,
    this.ttsHighlightStart,
    this.ttsHighlightEnd,
    this.onSelectionChanged,
    this.columnSpacing = 8.0,
  }) : assert(columnSpacing >= 0);

  final List<TextSegment> segments;
  final TextStyle? baseStyle;
  final String? query;
  final int? targetLineNumber;
  final int? ttsHighlightStart;
  final int? ttsHighlightEnd;
  final ValueChanged<String?>? onSelectionChanged;
  final double columnSpacing;

  @override
  State<VerticalTextViewer> createState() => _VerticalTextViewerState();
}

// Layout constants
const _kHorizontalPadding = 32.0;
const _kVerticalPadding = 62.0;
const _kTextHeight = 1.1;
const _kDefaultFontSize = 14.0;

// Page transition animation constants
const _kPageTransitionDuration = Duration(milliseconds: 250);
const _kPageTransitionCurve = Curves.easeInOut;

class _VerticalTextViewerState extends State<VerticalTextViewer>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  int _pageCount = 1;
  final FocusNode _focusNode = FocusNode();

  // Split segments into lines for pagination
  List<List<TextSegment>> _lines = [];

  // Cache TextPainter for character metrics
  TextPainter? _cachedPainter;
  TextStyle? _cachedStyle;

  // Page transition animation state
  late final AnimationController _animationController;
  late final CurvedAnimation _curvedAnimation;
  List<TextSegment>? _outgoingSegments;
  int _slideDirection = 1; // +1 = right (next), -1 = left (previous)
  List<TextSegment> _currentPageSegments = const [];
  BoxConstraints? _lastConstraints;

  @override
  void initState() {
    super.initState();
    _lines = _splitIntoLines(widget.segments);
    _targetLine = widget.targetLineNumber;
    _animationController = AnimationController(
      vsync: this,
      duration: _kPageTransitionDuration,
    )..addStatusListener(_onAnimationStatus);
    _curvedAnimation = CurvedAnimation(
      parent: _animationController,
      curve: _kPageTransitionCurve,
    );
  }

  @override
  void didUpdateWidget(VerticalTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments) {
      _lines = _splitIntoLines(widget.segments);
      _currentPage = 0;
      if (_animationController.isAnimating) {
        _animationController.stop();
        _outgoingSegments = null;
      }
    }
    if (widget.targetLineNumber != null &&
        widget.targetLineNumber != oldWidget.targetLineNumber) {
      setState(() { _targetLine = widget.targetLineNumber; });
    }
    if (widget.ttsHighlightStart != null &&
        widget.ttsHighlightStart != oldWidget.ttsHighlightStart) {
      _pendingTtsOffset = widget.ttsHighlightStart;
    }
  }

  int? _pendingTtsOffset;

  @override
  void dispose() {
    _curvedAnimation.dispose();
    _animationController.dispose();
    _focusNode.dispose();
    _cachedPainter?.dispose();
    super.dispose();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _outgoingSegments = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerSignal: _handlePointerSignal,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final result = _paginateLines(constraints);
            final pages = result.pages;
            final totalPages = pages.length;
            _pageCount = totalPages;

            if (result.targetPage != null &&
                result.targetPage != _currentPage) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _currentPage = result.targetPage!;
                  _targetLine = null;
                });
              });
            }

            // Cancel animation on layout change
            if (_lastConstraints != constraints && _animationController.isAnimating) {
              _animationController.stop();
              _outgoingSegments = null;
            }
            _lastConstraints = constraints;

            final safePage = totalPages == 0
                ? 0
                : _currentPage.clamp(0, totalPages - 1);

            final currentSegments =
                totalPages > 0 ? pages[safePage] : <TextSegment>[];
            _currentPageSegments = currentSegments;

            // Auto-navigate to TTS highlight page
            if (_pendingTtsOffset != null && totalPages > 1) {
              final ttsPage = _findPageForOffset(
                  _pendingTtsOffset!, result.charOffsetPerPage);
              if (ttsPage != null && ttsPage != safePage) {
                _pendingTtsOffset = null;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _goToPage(ttsPage);
                });
              } else {
                _pendingTtsOffset = null;
              }
            }

            final pageTextOffset = result.charOffsetPerPage[safePage];
            final lineBreakIndices = result.lineBreakIndicesPerPage[safePage];

            final incomingPage = Align(
              alignment: Alignment.topRight,
              child: VerticalTextPage(
                segments: currentSegments,
                baseStyle: widget.baseStyle,
                query: widget.query,
                ttsHighlightStart: widget.ttsHighlightStart,
                ttsHighlightEnd: widget.ttsHighlightEnd,
                pageStartTextOffset: pageTextOffset,
                lineBreakEntryIndices: lineBreakIndices,
                onSelectionChanged: widget.onSelectionChanged,
                onSwipe: _handleSwipe,
                columnSpacing: widget.columnSpacing,
              ),
            );

            final Widget pageContent;
            if (_outgoingSegments != null) {
              final slideOut = Tween<Offset>(
                begin: Offset.zero,
                end: Offset(_slideDirection.toDouble(), 0),
              ).animate(_curvedAnimation);
              final slideIn = Tween<Offset>(
                begin: Offset(-_slideDirection.toDouble(), 0),
                end: Offset.zero,
              ).animate(_curvedAnimation);
              pageContent = Stack(
                children: [
                  SlideTransition(
                    position: slideOut,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: VerticalTextPage(
                        segments: _outgoingSegments!,
                        baseStyle: widget.baseStyle,
                        query: widget.query,
                        columnSpacing: widget.columnSpacing,
                      ),
                    ),
                  ),
                  SlideTransition(
                    position: slideIn,
                    child: incomingPage,
                  ),
                ],
              );
            } else {
              pageContent = incomingPage;
            }

            return Column(
              children: [
                Expanded(
                  child: ClipRect(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: pageContent,
                    ),
                  ),
                ),
                if (totalPages > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      '${safePage + 1} / $totalPages',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _nextPage();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _previousPage();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (_animationController.isAnimating) return;

    _focusNode.requestFocus();

    if (event.scrollDelta.dy > 0) {
      _nextPage();
    } else if (event.scrollDelta.dy < 0) {
      _previousPage();
    }
  }

  void _handleSwipe(SwipeDirection direction) {
    direction == SwipeDirection.right ? _nextPage() : _previousPage();
  }

  void _changePage(int delta) {
    if (_pageCount <= 0) return;

    final newPage = (_currentPage + delta).clamp(0, _pageCount - 1);
    if (newPage == _currentPage) return;

    setState(() {
      _outgoingSegments = _currentPageSegments;
      _slideDirection = delta.sign;
      _currentPage = newPage;
    });

    _animationController
      ..reset()
      ..forward();
    widget.onSelectionChanged?.call(null);
  }

  void _nextPage() => _changePage(1);
  void _previousPage() => _changePage(-1);

  void _goToPage(int page) =>
      _changePage(page - _currentPage);

  int? _findPageForOffset(int offset, List<int> charOffsetPerPage) {
    for (var i = charOffsetPerPage.length - 1; i >= 0; i--) {
      if (offset >= charOffsetPerPage[i]) return i;
    }
    return null;
  }

  int? _targetLine;

  _PaginationResult _paginateLines(BoxConstraints constraints) {
    final style = widget.baseStyle?.copyWith(height: _kTextHeight) ??
        const TextStyle(fontSize: _kDefaultFontSize, height: _kTextHeight);

    // Reuse cached painter if style hasn't changed
    if (_cachedPainter == null || _cachedStyle != style) {
      _cachedPainter?.dispose();
      _cachedPainter = TextPainter(
        text: TextSpan(text: 'あ', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      _cachedStyle = style;
    }

    final charHeight = _cachedPainter!.height;
    // Use fontSize (not TextPainter.width) because each character is rendered
    // inside a SizedBox(width: fontSize) in VerticalTextPage.
    final charWidth = style.fontSize ?? _kDefaultFontSize;
    final availableWidth = constraints.maxWidth - _kHorizontalPadding;
    final availableHeight = constraints.maxHeight - _kVerticalPadding;

    final charsPerColumn =
        availableHeight > 0 ? (availableHeight / charHeight).floor() : 1;

    if (availableWidth <= 0 || charsPerColumn <= 0) {
      return _PaginationResult([widget.segments], null, const [0], const [{}]);
    }

    final columns = <List<TextSegment>>[];
    final lineStartColumns = _buildColumns(charsPerColumn, columns);
    final lineStartSet = lineStartColumns.skip(1).toSet();
    final (pages, pageStarts, lineBreakIndicesPerPage) =
        _groupColumnsIntoPages(columns, charWidth, availableWidth, lineStartSet);

    if (pages.isEmpty) {
      return _PaginationResult([widget.segments], null, const [0], const [{}]);
    }

    // Compute character offset per page for TTS auto-navigation
    final charOffsetPerPage = computeCharOffsetPerPage(columns, pageStarts, lineStartColumns);

    final targetPage =
        _findTargetPage(lineStartColumns, pageStarts, pages.length);
    return _PaginationResult(pages, targetPage, charOffsetPerPage, lineBreakIndicesPerPage);
  }

  List<List<TextSegment>> _splitIntoLines(List<TextSegment> segments) {
    final lines = <List<TextSegment>>[[]];

    for (final segment in segments) {
      if (segment case PlainTextSegment(:final text)) {
        _addPlainTextLines(text, lines);
      } else {
        lines.last.add(segment);
      }
    }

    return lines;
  }

  void _addPlainTextLines(String text, List<List<TextSegment>> lines) {
    final parts = text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) lines.add([]);
      if (parts[i].isNotEmpty) {
        lines.last.add(PlainTextSegment(parts[i]));
      }
    }
  }


  List<int> _buildColumns(int charsPerColumn, List<List<TextSegment>> columns) {
    final lineStartColumns = <int>[];
    for (final line in _lines) {
      lineStartColumns.add(columns.length);
      if (line.isEmpty) {
        columns.add([]);
      } else {
        final entries = flattenSegments(line);
        final entryColumns = splitWithKinsoku(entries, charsPerColumn);
        columns.addAll(buildColumnsFromEntries(entryColumns));
      }
    }
    return lineStartColumns;
  }

  /// Groups columns into pages using width-based greedy packing.
  /// Empty columns (from blank lines) occupy the same visual width as text
  /// columns, matching horizontal mode where blank lines take full line height.
  /// In the Wrap layout, an empty column's sentinel newline is rendered with
  /// charWidth, so it acts as a visible spacer without needing a separate
  /// character run.
  (List<List<TextSegment>>, List<int>, List<Set<int>>) _groupColumnsIntoPages(
    List<List<TextSegment>> columns,
    double charWidth,
    double availableWidth,
    Set<int> lineStartSet,
  ) {
    final pages = <List<TextSegment>>[];
    final pageStarts = <int>[];
    final lineBreakIndicesPerPage = <Set<int>>[];
    var start = 0;

    while (start < columns.length) {
      pageStarts.add(start);
      var end = start;
      var runCount = 0;
      var textWidth = 0.0;

      while (end < columns.length) {
        final hasText = columns[end].isNotEmpty;
        var runs = runCount;
        var width = textWidth;

        // All columns occupy charWidth (empty columns via sentinel, text via character run)
        width += charWidth;
        // Sentinel run between adjacent columns
        if (end > start) runs += 1;
        // Text columns add an extra run for characters
        if (hasText) runs += 1;

        final totalWidth = width + (runs > 1 ? (runs - 1) * widget.columnSpacing : 0.0);

        if (end > start && totalWidth > availableWidth) break;

        runCount = runs;
        textWidth = width;
        end++;
      }

      // Ensure at least 1 column per page
      if (end == start) end = start + 1;

      final pageSegments = <TextSegment>[];
      final lineBreakIndices = <int>{};
      var entryIndex = 0;
      for (var j = start; j < end; j++) {
        if (j > start) {
          if (lineStartSet.contains(j)) {
            lineBreakIndices.add(entryIndex);
          }
          pageSegments.add(const PlainTextSegment('\n'));
          entryIndex += 1;
        }
        for (final seg in columns[j]) {
          entryIndex += switch (seg) {
            PlainTextSegment(:final text) => text.runes.length,
            RubyTextSegment() => 1,
          };
        }
        pageSegments.addAll(columns[j]);
      }
      pages.add(pageSegments);
      lineBreakIndicesPerPage.add(lineBreakIndices);
      start = end;
    }

    return (pages, pageStarts, lineBreakIndicesPerPage);
  }

  int? _findTargetPage(
    List<int> lineStartColumns,
    List<int> pageStarts,
    int totalPages,
  ) {
    if (_targetLine == null) return null;

    final targetLineIndex = (_targetLine! - 1).clamp(0, _lines.length - 1);
    if (targetLineIndex >= lineStartColumns.length) return null;

    final colIndex = lineStartColumns[targetLineIndex];

    // Find which page contains this column using page start boundaries
    for (var i = pageStarts.length - 1; i >= 0; i--) {
      if (colIndex >= pageStarts[i]) {
        return i < totalPages ? i : null;
      }
    }
    return null;
  }

}

class _PaginationResult {
  const _PaginationResult(this.pages, this.targetPage, this.charOffsetPerPage, this.lineBreakIndicesPerPage);
  final List<List<TextSegment>> pages;
  final int? targetPage;
  final List<int> charOffsetPerPage;
  final List<Set<int>> lineBreakIndicesPerPage;
}
