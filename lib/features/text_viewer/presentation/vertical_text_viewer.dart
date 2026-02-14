import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';

class VerticalTextViewer extends StatefulWidget {
  const VerticalTextViewer({
    super.key,
    required this.segments,
    required this.baseStyle,
    this.query,
    this.targetLineNumber,
    this.onSelectionChanged,
  });

  final List<TextSegment> segments;
  final TextStyle? baseStyle;
  final String? query;
  final int? targetLineNumber;
  final ValueChanged<String?>? onSelectionChanged;

  @override
  State<VerticalTextViewer> createState() => _VerticalTextViewerState();
}

// Layout constants
const _kHorizontalPadding = 32.0;
const _kVerticalPadding = 62.0;
const _kRunSpacing = 4.0;
const _kTextHeight = 1.1;
const _kDefaultFontSize = 14.0;

class _VerticalTextViewerState extends State<VerticalTextViewer> {
  int _currentPage = 0;
  int _pageCount = 1;
  final FocusNode _focusNode = FocusNode();

  // Split segments into lines for pagination
  List<List<TextSegment>> _lines = [];

  // Cache TextPainter for character metrics
  TextPainter? _cachedPainter;
  TextStyle? _cachedStyle;

  @override
  void initState() {
    super.initState();
    _lines = _splitIntoLines(widget.segments);
    _targetLine = widget.targetLineNumber;
  }

  @override
  void didUpdateWidget(VerticalTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments) {
      _lines = _splitIntoLines(widget.segments);
      _currentPage = 0;
    }
    if (widget.targetLineNumber != null &&
        widget.targetLineNumber != oldWidget.targetLineNumber) {
      _navigateToLine(widget.targetLineNumber!);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _cachedPainter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        onPointerDown: (_) => _focusNode.requestFocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final result = _paginateLines(constraints);
            final pages = result.pages;
            _pageCount = pages.length;
            final totalPages = pages.length;

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

            final safePage = totalPages == 0
                ? 0
                : _currentPage.clamp(0, totalPages - 1);

            final currentSegments =
                totalPages > 0 ? pages[safePage] : <TextSegment>[];

            return Column(
              children: [
                Expanded(
                  child: ClipRect(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: VerticalTextPage(
                          segments: currentSegments,
                          baseStyle: widget.baseStyle,
                          query: widget.query,
                          onSelectionChanged: widget.onSelectionChanged,
                        ),
                      ),
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

  void _changePage(int delta) {
    if (_pageCount > 0) {
      setState(() {
        _currentPage = (_currentPage + delta).clamp(0, _pageCount - 1);
      });
      widget.onSelectionChanged?.call(null);
    }
  }

  void _nextPage() => _changePage(1);
  void _previousPage() => _changePage(-1);

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
    final charWidth = _cachedPainter!.width;
    final availableWidth = constraints.maxWidth - _kHorizontalPadding;
    final availableHeight = constraints.maxHeight - _kVerticalPadding;

    // Account for Wrap sentinel SizedBoxes that cause double runSpacing
    // between columns. For n columns: actual width = n*charWidth + (2n-2)*runSpacing
    // Solving for n: n <= (availableWidth + 2*runSpacing) / (charWidth + 2*runSpacing)
    final effectiveColumnWidth = charWidth + 2 * _kRunSpacing;
    final maxColumnsPerPage = availableWidth > 0
        ? ((availableWidth + 2 * _kRunSpacing) / effectiveColumnWidth).floor()
        : 1;
    final charsPerColumn =
        availableHeight > 0 ? (availableHeight / charHeight).floor() : 1;

    if (maxColumnsPerPage <= 0 || charsPerColumn <= 0) {
      return _PaginationResult([widget.segments], null);
    }

    final columns = <List<TextSegment>>[];
    final lineStartColumns = _buildColumns(charsPerColumn, columns);
    final pages = _groupColumnsIntoPages(columns, maxColumnsPerPage);
    final targetPage = _findTargetPage(lineStartColumns, maxColumnsPerPage, pages);

    return pages.isEmpty
        ? _PaginationResult([widget.segments], null)
        : _PaginationResult(pages, targetPage);
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
      _splitLineIntoColumns(line, charsPerColumn, columns);
    }
    return lineStartColumns;
  }

  List<List<TextSegment>> _groupColumnsIntoPages(
    List<List<TextSegment>> columns,
    int maxColumnsPerPage,
  ) {
    final pages = <List<TextSegment>>[];
    for (var i = 0; i < columns.length; i += maxColumnsPerPage) {
      final end = (i + maxColumnsPerPage).clamp(0, columns.length);
      final pageSegments = <TextSegment>[];
      for (var j = i; j < end; j++) {
        if (j > i) pageSegments.add(const PlainTextSegment('\n'));
        pageSegments.addAll(columns[j]);
      }
      pages.add(pageSegments);
    }
    return pages;
  }

  int? _findTargetPage(
    List<int> lineStartColumns,
    int maxColumnsPerPage,
    List<List<TextSegment>> pages,
  ) {
    final targetLine = _targetLine;
    if (targetLine == null) return null;

    final targetLineIndex = (targetLine - 1).clamp(0, _lines.length - 1);
    if (targetLineIndex >= lineStartColumns.length) return null;

    final colIndex = lineStartColumns[targetLineIndex];
    final targetPage = colIndex ~/ maxColumnsPerPage;
    if (targetPage >= 0 && targetPage < pages.length) {
      return targetPage;
    }
    return null;
  }

  void _splitLineIntoColumns(
    List<TextSegment> line,
    int charsPerColumn,
    List<List<TextSegment>> columns,
  ) {
    if (line.isEmpty) {
      columns.add([]);
      return;
    }

    var currentColumn = <TextSegment>[];
    var currentCount = 0;

    for (final segment in line) {
      if (segment case PlainTextSegment(:final text)) {
        (currentColumn, currentCount) = _addPlainTextToColumns(
          text,
          charsPerColumn,
          currentColumn,
          currentCount,
          columns,
        );
      } else if (segment case RubyTextSegment(:final base)) {
        (currentColumn, currentCount) = _addRubyTextToColumns(
          segment,
          base,
          charsPerColumn,
          currentColumn,
          currentCount,
          columns,
        );
      }
    }

    if (currentColumn.isNotEmpty) {
      columns.add(currentColumn);
    }
  }

  (List<TextSegment>, int) _addPlainTextToColumns(
    String text,
    int charsPerColumn,
    List<TextSegment> currentColumn,
    int currentCount,
    List<List<TextSegment>> columns,
  ) {
    final runes = text.runes.toList();
    var start = 0;

    while (start < runes.length) {
      final remaining = charsPerColumn - currentCount;
      final chunkEnd = (start + remaining).clamp(0, runes.length);
      final chunk = String.fromCharCodes(runes.sublist(start, chunkEnd));

      if (chunk.isNotEmpty) {
        currentColumn.add(PlainTextSegment(chunk));
      }

      currentCount += chunkEnd - start;
      start = chunkEnd;

      if (currentCount >= charsPerColumn) {
        columns.add(currentColumn);
        currentColumn = <TextSegment>[];
        currentCount = 0;
      }
    }

    return (currentColumn, currentCount);
  }

  (List<TextSegment>, int) _addRubyTextToColumns(
    RubyTextSegment segment,
    String base,
    int charsPerColumn,
    List<TextSegment> currentColumn,
    int currentCount,
    List<List<TextSegment>> columns,
  ) {
    final rubyChars = base.runes.length;

    if (currentCount + rubyChars > charsPerColumn && currentColumn.isNotEmpty) {
      columns.add(currentColumn);
      currentColumn = <TextSegment>[];
      currentCount = 0;
    }

    currentColumn.add(segment);
    currentCount += rubyChars;

    if (currentCount >= charsPerColumn) {
      columns.add(currentColumn);
      return (<TextSegment>[], 0);
    }

    return (currentColumn, currentCount);
  }
}

class _PaginationResult {
  const _PaginationResult(this.pages, this.targetPage);
  final List<List<TextSegment>> pages;
  final int? targetPage;
}
