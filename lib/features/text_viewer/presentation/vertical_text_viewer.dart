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
  });

  final List<TextSegment> segments;
  final TextStyle? baseStyle;
  final String? query;
  final int? targetLineNumber;

  @override
  State<VerticalTextViewer> createState() => _VerticalTextViewerState();
}

class _VerticalTextViewerState extends State<VerticalTextViewer> {
  int _currentPage = 0;
  final FocusNode _focusNode = FocusNode();

  // Split segments into lines for pagination
  List<List<TextSegment>> _lines = [];

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pages = _paginateLines(constraints);
            final totalPages = pages.length;
            final safePage = totalPages == 0
                ? 0
                : _currentPage.clamp(0, totalPages - 1);

            final currentSegments =
                totalPages > 0 ? pages[safePage] : <TextSegment>[];

            return Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: VerticalTextPage(
                        segments: currentSegments,
                        baseStyle: widget.baseStyle,
                        query: widget.query,
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

  void _nextPage() {
    // In the current LayoutBuilder we don't have the page count cached,
    // but we can safely increment and let build() clamp it.
    setState(() {
      _currentPage++;
    });
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
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

  List<List<TextSegment>> _splitIntoLines(List<TextSegment> segments) {
    final lines = <List<TextSegment>>[[]];

    for (final segment in segments) {
      switch (segment) {
        case PlainTextSegment(:final text):
          final parts = text.split('\n');
          for (var i = 0; i < parts.length; i++) {
            if (i > 0) {
              lines.add([]);
            }
            if (parts[i].isNotEmpty) {
              lines.last.add(PlainTextSegment(parts[i]));
            }
          }
        case RubyTextSegment():
          lines.last.add(segment);
      }
    }

    return lines;
  }

  List<List<TextSegment>> _paginateLines(BoxConstraints constraints) {
    final fontSize = widget.baseStyle?.fontSize ?? 14.0;
    final availableWidth = constraints.maxWidth - 32.0;

    final columnsPerPage = _calculateColumnsPerPage(
      availableWidth,
      fontSize + 8.0, // character width + run spacing
    );

    if (columnsPerPage <= 0) {
      return [widget.segments];
    }

    final pages = [
      for (var i = 0; i < _lines.length; i += columnsPerPage)
        _buildPageSegments(i, columnsPerPage),
    ];

    _updateCurrentPageForTarget(columnsPerPage, pages.length);

    return pages.isEmpty ? [widget.segments] : pages;
  }

  int _calculateColumnsPerPage(double availableWidth, double columnWidth) {
    return availableWidth > 0 ? (availableWidth / columnWidth).floor() : 1;
  }

  List<TextSegment> _buildPageSegments(int startIndex, int columnsPerPage) {
    final end = (startIndex + columnsPerPage).clamp(0, _lines.length);
    final pageLines = _lines.sublist(startIndex, end);

    return [
      for (var j = 0; j < pageLines.length; j++) ...[
        if (j > 0) const PlainTextSegment('\n'),
        ...pageLines[j],
      ],
    ];
  }

  void _updateCurrentPageForTarget(int columnsPerPage, int totalPages) {
    if (_targetLine != null) {
      final targetPage = (_targetLine! - 1) ~/ columnsPerPage;
      if (targetPage >= 0 && targetPage < totalPages) {
        _currentPage = targetPage;
      }
      _targetLine = null;
    }
  }
}
