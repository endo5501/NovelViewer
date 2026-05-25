import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/episode_navigation/domain/file_entry_start_intent.dart';
import 'package:novel_viewer/features/episode_navigation/providers/pending_file_entry_intent_provider.dart';
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
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/episode_navigation_buttons.dart';
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
/// This counts raw content characters and so is **not** suitable for feeding
/// into [TextPainter.getOffsetForCaret] when the TextSpan tree contains
/// [WidgetSpan]s (each [WidgetSpan] collapses a multi-character markup run
/// in the raw content down to a single placeholder character in the painter).
/// For TextPainter-space offsets, use [computeTextPainterLineStartOffsets].
@visibleForTesting
List<int> computeLineStartOffsets(String content) {
  final offsets = <int>[0];
  for (var i = 0; i < content.length; i++) {
    if (content.codeUnitAt(i) == 0x0A) offsets.add(i + 1);
  }
  return offsets;
}

/// Returns the TextPainter caret offset where each line starts when [segments]
/// are flattened into the `TextSpan` tree built by `buildRubyTextSpans` (one
/// caret unit per plain character, one caret unit per ruby [WidgetSpan]
/// regardless of the markup length in the original file).
///
/// This is the offset space [TextPainter.getOffsetForCaret] expects, so it is
/// what `_measureLineNumberOffset` and `_bookmarkLineYsFor` must use to land
/// on the correct rendered line.
@visibleForTesting
List<int> computeTextPainterLineStartOffsets(List<TextSegment> segments) {
  final offsets = <int>[0];
  var painterOffset = 0;
  for (final seg in segments) {
    switch (seg) {
      case PlainTextSegment(:final text):
        for (var i = 0; i < text.length; i++) {
          if (text.codeUnitAt(i) == 0x0A) {
            offsets.add(painterOffset + i + 1);
          }
        }
        painterOffset += text.length;
      case RubyTextSegment():
        painterOffset += 1; // WidgetSpan placeholder = 1 caret unit
    }
  }
  return offsets;
}

/// Returns the Y coordinate of the caret at [globalCharOffset] when
/// [textSpan] is laid out with [maxWidth].
///
/// [globalCharOffset] is in TextPainter caret-offset space — for content
/// containing ruby annotations, compute it via
/// [computeTextPainterLineStartOffsets] (which collapses each
/// [WidgetSpan] to one caret unit) rather than from raw content offsets.
///
/// Each [WidgetSpan] is given placeholder dimensions by
/// [_placeholderDimensionsFor]: for [RubyTextWidget] the width is measured
/// exactly with a sub-TextPainter over the base and ruby text (so half-width
/// glyphs are not double-counted) and the height is approximated as
/// `1.5 × fontSize` to account for the ruby gloss stacked above the base.
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
        // Width estimate: `chars * fontSize` is correct for full-width CJK
        // glyphs (~1em each) but ~2× too wide for half-width Latin / kana.
        // Measure both base and ruby text via TextPainter so the placeholder
        // matches the actual `Column[rubyText, base]` width exactly, which
        // keeps line wrap aligned with SelectableText.rich.
        final baseLineStyle = (w.baseStyle ?? const TextStyle())
            .copyWith(height: 1.0);
        final basePainter = TextPainter(
          text: TextSpan(text: w.base, style: baseLineStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final baseWidth = basePainter.width;
        basePainter.dispose();

        final rubyStyle = baseLineStyle.copyWith(fontSize: fontSize * 0.5);
        final rubyPainter = TextPainter(
          text: TextSpan(text: w.rubyText, style: rubyStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final rubyWidth = rubyPainter.width;
        rubyPainter.dispose();

        final width = baseWidth > rubyWidth ? baseWidth : rubyWidth;
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

  // Cached TextPainter-space offsets of each line start, derived from the
  // parsed segments (so that ruby `WidgetSpan`s count as 1 caret unit each
  // rather than the raw markup length). Indexed by 0-based line number.
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

  // True when a `FileEntryStartIntent.fromEnd` was consumed and we still owe
  // a `jumpTo(maxScrollExtent)` once layout settles. Cleared after the jump.
  bool _jumpToEndPending = false;

  // True when a `FileEntryStartIntent.fromStart` was consumed and we still
  // owe a `jumpTo(0)` once the new content has settled. Cleared after the
  // jump. Without this, the ScrollController retains the previous file's
  // pixel offset across a content swap and the user lands mid-file instead
  // of at the top.
  bool _jumpToStartPending = false;

  // Tracks whether the scroll view is currently parked at its first or last
  // line. Drives visibility of the prev/next episode buttons so they only
  // appear when the user is at a natural reading boundary — not in the
  // middle, where they would overlap body text.
  bool _atScrollTop = true;
  bool _atScrollBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateCurrentViewLine);
    _scrollController.addListener(_updateScrollEdgeFlags);
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
    _consumeFileEntryIntent();
    // First layout may produce a maxScrollExtent of 0 (single-page content);
    // capture the initial edge state after the frame so the single-page
    // bottom-button visibility is correct from the start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateScrollEdgeFlags();
    });
  }

  /// Refreshes [_atScrollTop] / [_atScrollBottom] from the current scroll
  /// position. Cheap; called from the existing scroll listener path. Skips
  /// `setState` when the flags would not change to avoid extra rebuilds on
  /// every scroll tick within the middle band.
  void _updateScrollEdgeFlags() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final newAtTop = pos.pixels <= pos.minScrollExtent;
    final newAtBottom = pos.pixels >= pos.maxScrollExtent;
    if (newAtTop == _atScrollTop && newAtBottom == _atScrollBottom) return;
    setState(() {
      _atScrollTop = newAtTop;
      _atScrollBottom = newAtBottom;
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
      _consumeFileEntryIntent();
    }
  }

  /// Reads the one-shot file-entry start intent on a content swap and queues
  /// the appropriate initial scroll. `fromEnd` triggers a jump to the bottom
  /// and `fromStart` (or a null intent on file switch) triggers a jump to
  /// the top once the new content has laid out. The non-`fromEnd` cases are
  /// not no-ops: the ScrollController carries the previous file's pixel
  /// offset across a content swap, which would land the user mid-file
  /// (often near the previous file's tail) instead of at the top of the new
  /// file — both for next-episode navigation (`fromStart`) and for plain
  /// file-browser clicks (null intent).
  ///
  /// Only the active display mode's renderer is allowed to consume the
  /// intent: in vertical mode the VerticalTextViewer owns it. Acting in
  /// vertical mode here would latch the pending flags, which are only
  /// drained inside the horizontal branch of build() — that would surface
  /// as a stray scroll on the next mode toggle.
  void _consumeFileEntryIntent() {
    if (ref.read(displayModeProvider) != TextDisplayMode.horizontal) return;
    final intent = ref.read(pendingFileEntryIntentProvider);
    if (intent == FileEntryStartIntent.fromEnd) {
      _jumpToEndPending = true;
    } else {
      // fromStart OR null after a content swap: reset to top so the
      // persisted ScrollController does not carry the previous file's
      // offset into the new file's layout.
      _jumpToStartPending = true;
    }
    // Clear only when an intent was actually set — a null intent does not
    // need clearing. Riverpod 3.x forbids life-cycle mutations, so defer
    // the clear to a microtask that runs after the build settles.
    if (intent != null) {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(pendingFileEntryIntentProvider.notifier).clear();
      });
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
    required List<TextSegment> segments,
    required InlineSpan textSpan,
    required double maxWidth,
    required double fontSize,
  }) {
    final lineStarts =
        _lineStartOffsets ??= computeTextPainterLineStartOffsets(segments);
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
    required List<TextSegment> segments,
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
        _lineStartOffsets ??= computeTextPainterLineStartOffsets(segments);
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
    required List<TextSegment> segments,
    required InlineSpan textSpan,
    required double maxWidth,
    required double fontSize,
  }) {
    if (!mounted || !_scrollController.hasClients) return;

    final maxOffset = _scrollController.position.maxScrollExtent;
    final clampedOffset = _measureLineNumberOffset(
      lineNumber: lineNumber,
      segments: segments,
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

    final scrollView = NotificationListener<ScrollNotification>(
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
                  segments: segments,
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
                segments: segments,
                textSpan: textSpan,
                maxWidth: textMaxWidth,
                fontSize: fontSize,
              );
              ref.read(bookmarkJumpLineProvider.notifier).clear();
            });
          }

          // `_jumpToEndPending` is consumed as its own block (not chained to
          // the if/else if above) so that, when a higher-priority scroll
          // target (search match / bookmark jump) is also pending, the flag
          // is still cleared in this build rather than leaking into a later
          // unrelated rebuild and surprising the user with a jump-to-bottom.
          if (_jumpToEndPending) {
            _jumpToEndPending = false;
            final hasHigherPriority =
                activeMatch != null || bookmarkJumpLine != null;
            if (!hasHigherPriority) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_scrollController.hasClients) return;
                if (!identical(widget.content, scheduledContent)) return;
                _scrollController
                    .jumpTo(_scrollController.position.maxScrollExtent);
              });
            }
          }

          // Mirror of the `_jumpToEndPending` block for the fromStart intent:
          // ensure the previous file's scroll offset does not leak into the
          // new file's layout when the user enters via the "Next →" button.
          if (_jumpToStartPending) {
            _jumpToStartPending = false;
            final hasHigherPriority =
                activeMatch != null || bookmarkJumpLine != null;
            if (!hasHigherPriority) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_scrollController.hasClients) return;
                if (!identical(widget.content, scheduledContent)) return;
                _scrollController.jumpTo(0);
              });
            }
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
                segments: segments,
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

    // Overlay the prev/next episode buttons only when the user is parked
    // at the very first or last line of the current file — in the middle
    // band they would obscure body text. The Stack is always returned (with
    // a conditional child) so the underlying scroll view's element identity
    // stays stable across visibility toggles — otherwise an unrelated
    // ScrollController state reset would clobber line / TTS / bookmark
    // scroll jumps that fire on the same frame.
    final showEdgeButtons = _atScrollTop || _atScrollBottom;
    return Stack(
      children: [
        scrollView,
        if (showEdgeButtons)
          Positioned(
            left: 8,
            bottom: 8,
            child: EpisodeNavigationButtons(
              showPrev: _atScrollTop,
              showNext: _atScrollBottom,
            ),
          ),
      ],
    );
  }
}

