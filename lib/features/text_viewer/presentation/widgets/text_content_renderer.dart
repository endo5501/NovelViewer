import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/llm_summary/presentation/analysis_runner.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/marked_words_provider.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/parsed_segments_cache_provider.dart';
import 'package:novel_viewer/features/text_viewer/data/ruby_text_parser.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/vertical_context_menu.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_repository.dart';
import 'package:novel_viewer/features/tts/presentation/dictionary_context_menu.dart';
import 'package:novel_viewer/features/tts/presentation/tts_dictionary_dialog.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/utils/content_hash.dart';

/// Returns the global character offset where each line starts in [content].
/// Index N (0-based) holds the start offset of the (N+1)th line.
///
/// Used by [TextContentRenderer] to translate a line number into a glyph
/// position before measuring its rendered Y coordinate with [TextPainter].
@visibleForTesting
List<int> computeLineStartOffsets(String content) {
  final offsets = <int>[0];
  for (var i = 0; i < content.length; i++) {
    if (content.codeUnitAt(i) == 0x0A) offsets.add(i + 1);
  }
  return offsets;
}

/// Returns the Y coordinate of the caret at [globalCharOffset] when
/// [textSpan] is laid out with [maxWidth].
///
/// Any [WidgetSpan] inside the tree is given an approximate placeholder
/// dimension derived from [fontSize] (with [RubyTextWidget] sized to its
/// `base.length × fontSize` width and `1.5 × fontSize` height to account for
/// the ruby gloss). This matches the actual `SelectableText.rich` layout
/// within roughly half a line, which is sufficient for scroll targeting.
@visibleForTesting
double measureCharOffsetY({
  required InlineSpan textSpan,
  required int globalCharOffset,
  required double maxWidth,
  required double fontSize,
}) {
  final dims = _placeholderDimensionsFor(textSpan, fontSize);
  final painter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
    textWidthBasis: TextWidthBasis.parent,
  );
  if (dims.isNotEmpty) painter.setPlaceholderDimensions(dims);
  painter.layout(maxWidth: maxWidth);
  final offset = painter.getOffsetForCaret(
    TextPosition(offset: globalCharOffset),
    Rect.zero,
  );
  painter.dispose();
  return offset.dy;
}

List<PlaceholderDimensions> _placeholderDimensionsFor(
    InlineSpan span, double fontSize) {
  final dims = <PlaceholderDimensions>[];
  span.visitChildren((child) {
    if (child is WidgetSpan) {
      final w = child.child;
      if (w is RubyTextWidget) {
        final width = w.base.characters.length * fontSize;
        // Ruby (≈0.5 × fontSize) stacked above base (≈1.0 × fontSize).
        final height = fontSize * 1.5;
        dims.add(PlaceholderDimensions(
          size: Size(width, height),
          alignment: child.alignment,
        ));
      } else {
        dims.add(PlaceholderDimensions(
          size: Size.zero,
          alignment: child.alignment,
        ));
      }
    }
    return true;
  });
  return dims;
}

/// Renders the text content of the currently open file in either horizontal
/// (SelectableText.rich) or vertical (VerticalTextViewer) mode. Owns the
/// scroll controller, search/TTS highlight application, ruby parsing cache
/// lookup, dictionary context-menu launch, bookmark indicators, and the
/// auto-scroll-to-TTS-highlight + manual-scroll-stops-TTS interactions.
class TextContentRenderer extends ConsumerStatefulWidget {
  const TextContentRenderer({super.key, required this.content});

  final String content;

  @override
  ConsumerState<TextContentRenderer> createState() =>
      _TextContentRendererState();
}

class _TextContentRendererState extends ConsumerState<TextContentRenderer> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrollKey;
  bool _isTtsScrolling = false;
  int _lastReportedViewLine = 0;
  // Memoised hash of `widget.content`. Recomputed only when the content
  // identity changes — sha256 over a 100KB+ novel is expensive on each
  // build (font/theme/playback ticks all rebuild this widget).
  String? _contentHash;
  // Last TTS highlight range we already scrolled to. Guards against
  // re-firing the auto-scroll animation on unrelated rebuilds while TTS
  // is active.
  TextRange? _lastTtsScrolledRange;

  // Memoised TextSpan tree for the horizontal mode. buildRubyTextSpans is
  // O(text.length × marks) and runs on every rebuild (font/theme/playback
  // tick), so the cache key compares its inputs by identity / value and we
  // reuse the previous tree when nothing changed.
  TextSpan? _cachedTextSpan;
  String? _cachedTextSpanContent;
  TextStyle? _cachedTextSpanStyle;
  String? _cachedTextSpanQuery;
  TextRange? _cachedTextSpanTtsRange;
  Map<String, MarkStyle>? _cachedTextSpanMarkedWords;
  Brightness? _cachedTextSpanBrightness;

  // Cached `\n` positions for the current content. Indexed by 0-based line
  // number; entry N is the global character offset where line N+1 starts.
  // Invalidated when `widget.content` identity changes (see didUpdateWidget).
  List<int>? _lineStartOffsets;

  // Memoised bookmark icon Y positions. Keyed by (content, textStyle,
  // maxWidth) — the values that actually affect the rendered text layout.
  // We deliberately do NOT key on textSpan identity because the cached
  // span is rebuilt on every TTS tick, mark change, brightness flip, and
  // search-query change, none of which affect line wrapping; keying on
  // those would force a full TextPainter relayout per TTS tick on a
  // 100K+ character document.
  String? _cachedBookmarkLayoutContent;
  TextStyle? _cachedBookmarkLayoutStyle;
  double? _cachedBookmarkLayoutMaxWidth;
  Map<int, double>? _cachedBookmarkLineYs;

  // Bookmark jumps are one-shot (the provider is cleared in the post-frame
  // callback), so a normal "same-value" guard like _lastScrollKey would
  // prevent re-jumping to the same line. Instead, gate scheduling on a
  // pending flag that resets when the queued callback runs.
  bool _bookmarkScrollPending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateCurrentViewLine);
    // Reset current view line when the user switches files.
    ref.listenManual(selectedFileProvider, (prev, next) {
      if (prev?.path != next?.path) {
        _lastScrollKey = null;
        _lastTtsScrolledRange = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(currentViewLineProvider.notifier).set(1);
          _lastReportedViewLine = 1;
        });
      }
    });
  }

  @override
  void didUpdateWidget(TextContentRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.content, widget.content)) {
      _contentHash = null;
      _lastTtsScrolledRange = null;
      _cachedTextSpan = null;
      _lineStartOffsets = null;
      _cachedBookmarkLayoutContent = null;
      _cachedBookmarkLayoutStyle = null;
      _cachedBookmarkLineYs = null;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showVerticalContextMenu(
      BuildContext context, Offset position, String selectedText) {
    final l10n = AppLocalizations.of(context)!;
    final renderObject =
        Overlay.maybeOf(context)?.context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final overlay = renderObject;
    showMenu<VerticalContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: buildVerticalContextMenuItems(
        copyLabel: l10n.contextMenu_copy,
        addToDictionaryLabel: l10n.contextMenu_addToDictionary,
        analyzeNoSpoilerLabel: l10n.contextMenu_analyzeNoSpoiler,
        analyzeSpoilerLabel: l10n.contextMenu_analyzeSpoiler,
      ),
    ).then((value) {
      if (value == null || !mounted) return;
      dispatchVerticalContextAction(
        value,
        selectedText: selectedText,
        onCopy: (t) => Clipboard.setData(ClipboardData(text: t)),
        onAddToDictionary: _openDictionaryDialog,
        onAnalyze: _runAnalysis,
      );
    });
  }

  void _openDictionaryDialog(String selectedText) {
    final folderPath = ref.read(currentDirectoryProvider);
    if (folderPath == null) return;
    final dictDb = ref.read(ttsDictionaryDatabaseProvider(folderPath));
    final dictRepo = TtsDictionaryRepository(dictDb);
    TtsDictionaryDialog.show(
      context,
      repository: dictRepo,
      initialSurface: selectedText,
    );
  }

  void _runAnalysis(String word, SummaryType type) {
    ref.read(analysisRunnerProvider).run(
          context: context,
          word: word,
          type: type,
        );
  }

  void _onMarkEnter(String word, Offset position, HoverToken token) {
    ref
        .read(hoverPopupProvider.notifier)
        .show(word: word, position: position, token: token);
  }

  void _onMarkExit(HoverToken token) {
    ref.read(hoverPopupProvider.notifier).hideIfShowing(token);
  }

  void _onHoverHideRequest() {
    ref.read(hoverPopupProvider.notifier).hide();
  }

  void _scrollToTtsHighlight(
      String content, TextRange range, TextStyle? textStyle) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final textBefore =
          content.substring(0, range.start.clamp(0, content.length));
      final lineNumber = '\n'.allMatches(textBefore).length;

      final fs = textStyle?.fontSize ?? 14.0;
      final lineHeight = (textStyle?.height ?? 1.5) * fs;
      final maxOffset = _scrollController.position.maxScrollExtent;
      final clampedOffset = (lineNumber * lineHeight).clamp(0.0, maxOffset);

      _isTtsScrolling = true;
      _scrollController
          .animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      )
          .then((_) {
        _isTtsScrolling = false;
      });
    });
  }

  void _updateCurrentViewLine() {
    if (!mounted || !_scrollController.hasClients) return;
    final fontSize = ref.read(fontSizeProvider);
    final fontFamily = ref.read(fontFamilyProvider);
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: fontSize,
          fontFamily: fontFamily.effectiveFontFamilyName,
        );
    final fs = textStyle?.fontSize ?? 14.0;
    final lineHeight = (textStyle?.height ?? 1.5) * fs;
    if (lineHeight <= 0) return;
    final lineNumber = (_scrollController.offset / lineHeight).floor() + 1;
    if (lineNumber != _lastReportedViewLine) {
      _lastReportedViewLine = lineNumber;
      ref.read(currentViewLineProvider.notifier).set(lineNumber);
    }
  }

  /// Y of the start of [lineNumber] (1-based) within [textSpan] when laid
  /// out with [maxWidth]. Falls back to 0 if the cached line offset table
  /// has not been populated yet or the line is out of range.
  double _measureLineNumberOffset({
    required int lineNumber,
    required InlineSpan textSpan,
    required double maxWidth,
    required double fontSize,
  }) {
    final lineStarts = _lineStartOffsets ??=
        computeLineStartOffsets(widget.content);
    final idx = lineNumber - 1;
    if (idx < 0 || idx >= lineStarts.length) return 0.0;
    return measureCharOffsetY(
      textSpan: textSpan,
      globalCharOffset: lineStarts[idx],
      maxWidth: maxWidth,
      fontSize: fontSize,
    );
  }

  /// Measures (and memoises) the Y position of every line in [lines] using a
  /// single shared [TextPainter] layout — paying the layout cost once per
  /// (content, style, maxWidth) combination rather than once per bookmark
  /// per rebuild.
  ///
  /// Returns a fresh map containing exactly [lines]; callers must never see
  /// keys for bookmarks that were removed since the cache was populated.
  Map<int, double> _bookmarkLineYsFor({
    required List<int> lines,
    required InlineSpan textSpan,
    required TextStyle? textStyle,
    required double maxWidth,
    required double fontSize,
  }) {
    if (lines.isEmpty) return const {};

    final cached = _cachedBookmarkLineYs;
    if (cached != null &&
        identical(_cachedBookmarkLayoutContent, widget.content) &&
        _cachedBookmarkLayoutStyle == textStyle &&
        _cachedBookmarkLayoutMaxWidth == maxWidth &&
        lines.every(cached.containsKey)) {
      // Filter to just the requested lines so a shrunk bookmark list does
      // not leak ghost icons from a prior wider set.
      return {for (final l in lines) l: cached[l]!};
    }

    final lineStarts =
        _lineStartOffsets ??= computeLineStartOffsets(widget.content);
    final dims = _placeholderDimensionsFor(textSpan, fontSize);
    final painter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textWidthBasis: TextWidthBasis.parent,
    );
    if (dims.isNotEmpty) painter.setPlaceholderDimensions(dims);
    painter.layout(maxWidth: maxWidth);

    final result = <int, double>{};
    for (final line in lines) {
      final idx = line - 1;
      if (idx < 0 || idx >= lineStarts.length) continue;
      result[line] = painter
          .getOffsetForCaret(
            TextPosition(offset: lineStarts[idx]),
            Rect.zero,
          )
          .dy;
    }
    painter.dispose();

    _cachedBookmarkLayoutContent = widget.content;
    _cachedBookmarkLayoutStyle = textStyle;
    _cachedBookmarkLayoutMaxWidth = maxWidth;
    _cachedBookmarkLineYs = result;
    return result;
  }

  void _scrollToLineNumber({
    required int lineNumber,
    required InlineSpan textSpan,
    required double maxWidth,
    required double fontSize,
  }) {
    if (!mounted || !_scrollController.hasClients) return;

    final maxOffset = _scrollController.position.maxScrollExtent;
    final clampedOffset = _measureLineNumberOffset(
      lineNumber: lineNumber,
      textSpan: textSpan,
      maxWidth: maxWidth,
      fontSize: fontSize,
    ).clamp(0.0, maxOffset);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFile = ref.watch(selectedFileProvider);
    final searchMatch = ref.watch(selectedSearchMatchProvider);
    final displayMode = ref.watch(displayModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final fontFamily = ref.watch(fontFamilyProvider);

    final activeMatch =
        searchMatch != null && selectedFile?.path == searchMatch.filePath
            ? searchMatch
            : null;

    final playbackState = ref.watch(ttsPlaybackStateProvider);
    final ttsHighlightRange = ref.watch(ttsHighlightRangeProvider);

    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: fontSize,
          fontFamily: fontFamily.effectiveFontFamilyName,
        );
    final hash = _contentHash ??= computeContentHash(widget.content);
    final segments = ref
        .watch(parsedSegmentsCacheProvider)
        .getOrParse(widget.content, hash, parseRubyText);

    final bookmarkJumpLine = ref.watch(bookmarkJumpLineProvider);
    final targetLineNumber = activeMatch?.lineNumber ?? bookmarkJumpLine;
    final bookmarkLines =
        ref.watch(bookmarkLineNumbersForFileProvider).value ?? [];
    final markedWords = ref.watch(markedWordsProvider);

    if (displayMode == TextDisplayMode.vertical) {
      // Clear bookmark jump after consuming in vertical mode.
      if (bookmarkJumpLine != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(bookmarkJumpLineProvider.notifier).clear();
        });
      }
      final columnSpacing = ref.watch(columnSpacingProvider);
      return VerticalTextViewer(
        segments: segments,
        baseStyle: textStyle,
        query: activeMatch?.query,
        targetLineNumber: targetLineNumber,
        ttsHighlightStart: ttsHighlightRange?.start,
        ttsHighlightEnd: ttsHighlightRange?.end,
        columnSpacing: columnSpacing,
        bookmarkLineNumbers: bookmarkLines,
        markedWords: markedWords,
        onMarkEnter: _onMarkEnter,
        onMarkExit: _onMarkExit,
        onHoverHideRequest: _onHoverHideRequest,
        onPageLineChanged: (lineNumber) {
          ref.read(currentViewLineProvider.notifier).set(lineNumber);
        },
        onSelectionChanged: (text) {
          ref.read(selectedTextProvider.notifier).setText(text);
        },
        onContextMenu: (position, selectedText) {
          _showVerticalContextMenu(context, position, selectedText);
        },
      );
    }

    // Horizontal mode
    final brightness = Theme.of(context).brightness;
    final query = activeMatch?.query;
    final cachedSpan = _cachedTextSpan;
    final TextSpan textSpan;
    if (cachedSpan != null &&
        identical(_cachedTextSpanContent, widget.content) &&
        _cachedTextSpanStyle == textStyle &&
        _cachedTextSpanQuery == query &&
        _cachedTextSpanTtsRange == ttsHighlightRange &&
        identical(_cachedTextSpanMarkedWords, markedWords) &&
        _cachedTextSpanBrightness == brightness) {
      textSpan = cachedSpan;
    } else {
      textSpan = buildRubyTextSpans(
        segments,
        textStyle,
        query,
        ttsHighlightRange: ttsHighlightRange,
        brightness: brightness,
        markedWords: markedWords,
        onMarkEnter: _onMarkEnter,
        onMarkExit: _onMarkExit,
      );
      _cachedTextSpan = textSpan;
      _cachedTextSpanContent = widget.content;
      _cachedTextSpanStyle = textStyle;
      _cachedTextSpanQuery = query;
      _cachedTextSpanTtsRange = ttsHighlightRange;
      _cachedTextSpanMarkedWords = markedWords;
      _cachedTextSpanBrightness = brightness;
    }

    if (ttsHighlightRange != null &&
        ttsHighlightRange != _lastTtsScrolledRange) {
      _lastTtsScrolledRange = ttsHighlightRange;
      _scrollToTtsHighlight(widget.content, ttsHighlightRange, textStyle);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!_isTtsScrolling &&
            notification is ScrollStartNotification &&
            notification.dragDetails != null &&
            playbackState == TtsPlaybackState.playing) {
          ref.read(ttsStopRequestProvider.notifier).request();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(builder: (context, constraints) {
          final bookmarkGutter = bookmarkLines.isEmpty ? 0.0 : 20.0;
          final textMaxWidth = constraints.maxWidth - bookmarkGutter;

          // Capture the content reference used to build textSpan/textMaxWidth
          // so the post-frame callback can detect a swap (file switch /
          // content reload) between scheduling and execution and skip
          // scrolling against a stale layout.
          final scheduledContent = widget.content;
          if (activeMatch != null) {
            final scrollKey =
                '${activeMatch.filePath}:${activeMatch.lineNumber}:${activeMatch.query}';
            if (scrollKey != _lastScrollKey) {
              _lastScrollKey = scrollKey;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (!identical(widget.content, scheduledContent)) return;
                _scrollToLineNumber(
                  lineNumber: activeMatch.lineNumber,
                  textSpan: textSpan,
                  maxWidth: textMaxWidth,
                  fontSize: fontSize,
                );
              });
            }
          } else if (bookmarkJumpLine != null && !_bookmarkScrollPending) {
            _bookmarkScrollPending = true;
            final targetLine = bookmarkJumpLine;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _bookmarkScrollPending = false;
              if (!mounted) return;
              if (!identical(widget.content, scheduledContent)) return;
              _scrollToLineNumber(
                lineNumber: targetLine,
                textSpan: textSpan,
                maxWidth: textMaxWidth,
                fontSize: fontSize,
              );
              ref.read(bookmarkJumpLineProvider.notifier).clear();
            });
          }

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(left: bookmarkGutter),
                child: SelectableText.rich(
                  textSpan,
                  onSelectionChanged: (selection, cause) {
                    final selectedText =
                        selectedTextFromSelection(selection, segments);
                    ref.read(selectedTextProvider.notifier).setText(
                          selectedText.isEmpty ? null : selectedText,
                        );
                  },
                  contextMenuBuilder: (menuContext, editableTextState) {
                    final selectedText = selectedTextFromSelection(
                      editableTextState.textEditingValue.selection,
                      segments,
                    );
                    return buildDictionaryContextMenu(
                      context,
                      editableTextState,
                      selectedText: selectedText,
                      onAddToDictionary: _openDictionaryDialog,
                      onAnalyze: _runAnalysis,
                    );
                  },
                ),
              ),
              ..._bookmarkLineYsFor(
                lines: bookmarkLines,
                textSpan: textSpan,
                textStyle: textStyle,
                maxWidth: textMaxWidth,
                fontSize: fontSize,
              ).entries.map(
                    (e) => Positioned(
                      left: 0,
                      top: e.value,
                      child: Icon(
                        Icons.bookmark,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
            ],
          );
        }),
      ),
    );
  }
}

