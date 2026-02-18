import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novel_viewer/features/text_viewer/data/swipe_detection.dart';
import 'package:novel_viewer/features/text_viewer/data/column_splitter.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';


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
    this.onUserPageChange,
    this.columnSpacing = 8.0,
  }) : assert(columnSpacing >= 0);

  final List<TextSegment> segments;
  final TextStyle? baseStyle;
  final String? query;
  final int? targetLineNumber;
  final int? ttsHighlightStart;
  final int? ttsHighlightEnd;
  final ValueChanged<String?>? onSelectionChanged;
  final VoidCallback? onUserPageChange;
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
      _navigateToLine(widget.targetLineNumber!);
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

            final incomingPage = Align(
              alignment: Alignment.topRight,
              child: VerticalTextPage(
                segments: currentSegments,
                baseStyle: widget.baseStyle,
                query: widget.query,
                ttsHighlightStart: widget.ttsHighlightStart,
                ttsHighlightEnd: widget.ttsHighlightEnd,
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
    widget.onUserPageChange?.call();
  }

  void _nextPage() => _changePage(1);
  void _previousPage() => _changePage(-1);

  void _goToPage(int page) {
    if (page == _currentPage || page < 0 || page >= _pageCount) return;
    final delta = page - _currentPage;
    setState(() {
      _outgoingSegments = _currentPageSegments;
      _slideDirection = delta.sign;
      _currentPage = page;
    });
    _animationController
      ..reset()
      ..forward();
  }

  int? _findPageForOffset(int offset, List<int> charOffsetPerPage) {
    for (var i = charOffsetPerPage.length - 1; i >= 0; i--) {
      if (offset >= charOffsetPerPage[i]) return i;
    }
    return null;
  }

  void _navigateToLine(int lineNumber) {
    // Estimate which page contains the target line.
    // This is approximate since actual page sizes depend on layout,
    // but we can use the line-based pagination as a heuristic.
    // For simplicity, we rebuild and let LayoutBuilder handle it.
    setState(() {
      _targetLine = lineNumber;
    });
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
      return _PaginationResult([widget.segments], null, const [0]);
    }

    final columns = <List<TextSegment>>[];
    final lineStartColumns = _buildColumns(charsPerColumn, columns);
    final (pages, pageStarts) =
        _groupColumnsIntoPages(columns, charWidth, availableWidth);

    if (pages.isEmpty) {
      return _PaginationResult([widget.segments], null, const [0]);
    }

    // Compute character offset per page for TTS auto-navigation
    final charOffsetPerPage = _computeCharOffsetPerPage(pages);

    final targetPage =
        _findTargetPage(lineStartColumns, pageStarts, pages.length);
    return _PaginationResult(pages, targetPage, charOffsetPerPage);
  }

  List<int> _computeCharOffsetPerPage(List<List<TextSegment>> pages) {
    final offsets = <int>[];
    var offset = 0;
    for (final page in pages) {
      offsets.add(offset);
      for (final segment in page) {
        switch (segment) {
          case PlainTextSegment(:final text):
            offset += text.length;
          case RubyTextSegment(:final base):
            offset += base.length;
        }
      }
    }
    return offsets;
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
  (List<List<TextSegment>>, List<int>) _groupColumnsIntoPages(
    List<List<TextSegment>> columns,
    double charWidth,
    double availableWidth,
  ) {
    final pages = <List<TextSegment>>[];
    final pageStarts = <int>[];
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
      for (var j = start; j < end; j++) {
        if (j > start) pageSegments.add(const PlainTextSegment('\n'));
        pageSegments.addAll(columns[j]);
      }
      pages.add(pageSegments);
      start = end;
    }

    return (pages, pageStarts);
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
  const _PaginationResult(this.pages, this.targetPage, this.charOffsetPerPage);
  final List<List<TextSegment>> pages;
  final int? targetPage;
  final List<int> charOffsetPerPage;
}
