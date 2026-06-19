import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/episode_navigation/domain/file_entry_start_intent.dart';
import 'package:novel_viewer/features/episode_navigation/providers/adjacent_files_provider.dart';
import 'package:novel_viewer/features/episode_navigation/providers/episode_navigation_controller.dart';
import 'package:novel_viewer/features/episode_navigation/providers/pending_file_entry_intent_provider.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/swipe_detection.dart';
import 'package:novel_viewer/features/text_viewer/data/column_splitter.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_intents.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Test-only counter incremented once each time the expensive pagination
/// layer actually recomputes (a cache miss). F115 memoizes the full-document
/// pagination keyed by (segments identity, constraints, style, columnSpacing);
/// tests reset this counter and assert it stays flat across rebuilds whose
/// keyed inputs are unchanged (TTS tick, query, bookmark/target changes) and
/// increments when a keyed input changes (constraints/style).
@visibleForTesting
int verticalPaginationHeavyCount = 0;

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

/// Pure, immutable snapshot of everything [resolveViewerEffects] needs to decide
/// which layout-derived side effects [VerticalTextViewer]'s build should fire.
///
/// Historically these decisions were inlined in `LayoutBuilder.builder` as five
/// effect schedulers entangled with six in-build field mutations (F156):
///   ① target-line page jump        (guarded by `scheduledTargetPage`)
///   ② cancel animation on layout change
///   ③ jump-to-last-page (`fromEnd` intent)
///   ④ TTS auto-navigate (animated, via `_changePage`)
///   ⑤ report current page's first line number
/// Lifting the decision into a pure function makes it unit-testable without a
/// widget tree and removes the in-layout flag mutations that made repeated
/// builds re-schedule one-shot effects.
@visibleForTesting
class ViewerEffectInputs {
  const ViewerEffectInputs({
    required this.totalPages,
    required this.currentPage,
    required this.targetPage,
    required this.scheduledTargetPage,
    required this.jumpToLastPagePending,
    required this.pendingTtsOffset,
    required this.charOffsetPerPage,
    required this.firstLinePerPage,
    required this.lastReportedLine,
    required this.constraintsChanged,
    required this.isAnimating,
  });

  final int totalPages;
  final int currentPage;
  final int? targetPage;
  final int? scheduledTargetPage;
  final bool jumpToLastPagePending;
  final int? pendingTtsOffset;
  final List<int> charOffsetPerPage;
  final List<int> firstLinePerPage;
  final int lastReportedLine;
  final bool constraintsChanged;
  final bool isAnimating;

  /// The page actually shown this build: current page clamped into range.
  int get safePage =>
      totalPages == 0 ? 0 : currentPage.clamp(0, totalPages - 1);
}

/// Command value describing the side effects a single build should apply.
/// All fields are scalar so the value is cheap to compare in tests.
///
/// Application is split: [cancelAnimation] / [newScheduledTargetPage] /
/// [consumeJumpToLastPage] / [consumeTtsOffset] / [reportLine] are applied
/// synchronously (so repeated builds before the post-frame fires cannot apply a
/// one-shot effect twice), while the page jumps, hover-hide and line callback
/// run in a single post-frame (see `_applyViewerEffects`).
@visibleForTesting
class ViewerEffects {
  const ViewerEffects({
    this.targetJumpToPage,
    this.lastJumpToPage,
    this.animatedGoToPage,
    this.reportLine,
    this.cancelAnimation = false,
    this.newScheduledTargetPage,
    this.consumeJumpToLastPage = false,
    this.consumeTtsOffset = false,
  });

  /// ① Page to jump to for a target-line navigation, via `setState`. Clears
  /// `_targetLine` and re-checks the page on apply. Null when ① does not fire.
  final int? targetJumpToPage;

  /// ③ Page to jump to for a `fromEnd` intent (always the last page), via
  /// `setState`. Applied unconditionally on the post-frame, matching the prior
  /// inline code. Kept independent of [targetJumpToPage]: when both fire in the
  /// same build they apply in order (① then ③), so the final page is the last
  /// page exactly as before. Null when ③ does not jump.
  final int? lastJumpToPage;

  /// Page to navigate to with the slide animation (④ TTS) via `_changePage`.
  final int? animatedGoToPage;

  /// First line number of the current page to report (⑤), or null if unchanged.
  final int? reportLine;

  /// ② Stop an in-flight page-transition animation (layout changed mid-anim).
  final bool cancelAnimation;

  /// Value to record into `_scheduledTargetPage` synchronously (① re-entrancy
  /// guard), or null when no target jump is scheduled.
  final int? newScheduledTargetPage;

  /// Clear `_jumpToLastPagePending` (③ consume).
  final bool consumeJumpToLastPage;

  /// Clear `_pendingTtsOffset` (④ consume).
  final bool consumeTtsOffset;

  static const none = ViewerEffects();

  @override
  bool operator ==(Object other) =>
      other is ViewerEffects &&
      other.targetJumpToPage == targetJumpToPage &&
      other.lastJumpToPage == lastJumpToPage &&
      other.animatedGoToPage == animatedGoToPage &&
      other.reportLine == reportLine &&
      other.cancelAnimation == cancelAnimation &&
      other.newScheduledTargetPage == newScheduledTargetPage &&
      other.consumeJumpToLastPage == consumeJumpToLastPage &&
      other.consumeTtsOffset == consumeTtsOffset;

  @override
  int get hashCode => Object.hash(
        targetJumpToPage,
        lastJumpToPage,
        animatedGoToPage,
        reportLine,
        cancelAnimation,
        newScheduledTargetPage,
        consumeJumpToLastPage,
        consumeTtsOffset,
      );

  @override
  String toString() => 'ViewerEffects('
      'targetJumpToPage: $targetJumpToPage, '
      'lastJumpToPage: $lastJumpToPage, '
      'animatedGoToPage: $animatedGoToPage, '
      'reportLine: $reportLine, '
      'cancelAnimation: $cancelAnimation, '
      'newScheduledTargetPage: $newScheduledTargetPage, '
      'consumeJumpToLastPage: $consumeJumpToLastPage, '
      'consumeTtsOffset: $consumeTtsOffset)';
}

/// Finds the last page whose start text-offset is `<= offset`, mirroring the
/// previous `_findPageForOffset` instance method. Pure so it can run inside
/// [resolveViewerEffects].
int? _findPageForOffset(int offset, List<int> charOffsetPerPage) {
  for (var i = charOffsetPerPage.length - 1; i >= 0; i--) {
    if (offset >= charOffsetPerPage[i]) return i;
  }
  return null;
}

/// Pure decision: given a layout snapshot, return the side effects this build
/// should apply. Behaviour mirrors the previous inline orchestration exactly,
/// including ordering: the target jump (①) and the last-page jump (③) are kept
/// as independent effects so that when both fire in the same build they apply
/// in order (① then ③) and the final page is the last page, just as the prior
/// two-post-frame code produced.
@visibleForTesting
ViewerEffects resolveViewerEffects(ViewerEffectInputs i) {
  final safePage = i.safePage;

  // ① Target-line page jump. The `scheduledTargetPage` check is the re-entrancy
  // guard against re-scheduling the same jump across rebuilds before the
  // post-frame fires.
  int? targetJumpToPage;
  int? newScheduledTargetPage;
  final targetFires = i.targetPage != null &&
      i.targetPage != i.currentPage &&
      i.targetPage != i.scheduledTargetPage;
  if (targetFires) {
    targetJumpToPage = i.targetPage;
    newScheduledTargetPage = i.targetPage;
  }

  // ③ Jump-to-last-page (`fromEnd` intent). Consumed whenever pending and pages
  // exist, even if the page is already last. Independent of ① (applied after
  // it), preserving the prior behaviour where the last-page jump ran last.
  var consumeJumpToLastPage = false;
  int? lastJumpToPage;
  if (i.jumpToLastPagePending && i.totalPages > 0) {
    consumeJumpToLastPage = true;
    final lastPage = i.totalPages - 1;
    if (lastPage != i.currentPage) {
      lastJumpToPage = lastPage;
    }
  }

  // ④ TTS auto-navigate (animated). Consumed whenever pending and more than one
  // page exists, regardless of whether a navigation is actually needed.
  int? animatedGoToPage;
  var consumeTtsOffset = false;
  if (i.pendingTtsOffset != null && i.totalPages > 1) {
    consumeTtsOffset = true;
    final ttsPage = _findPageForOffset(i.pendingTtsOffset!, i.charOffsetPerPage);
    if (ttsPage != null && ttsPage != safePage) {
      animatedGoToPage = ttsPage;
    }
  }

  // ⑤ Report the current page's first line number when it changes.
  int? reportLine;
  if (i.firstLinePerPage.isNotEmpty && safePage < i.firstLinePerPage.length) {
    final pageLine = i.firstLinePerPage[safePage];
    if (pageLine != i.lastReportedLine) {
      reportLine = pageLine;
    }
  }

  // ② Cancel an in-flight page-transition animation on a layout change.
  final cancelAnimation = i.constraintsChanged && i.isAnimating;

  return ViewerEffects(
    targetJumpToPage: targetJumpToPage,
    lastJumpToPage: lastJumpToPage,
    animatedGoToPage: animatedGoToPage,
    reportLine: reportLine,
    cancelAnimation: cancelAnimation,
    newScheduledTargetPage: newScheduledTargetPage,
    consumeJumpToLastPage: consumeJumpToLastPage,
    consumeTtsOffset: consumeTtsOffset,
  );
}

class VerticalTextViewer extends ConsumerStatefulWidget {
  const VerticalTextViewer({
    super.key,
    required this.segments,
    required this.baseStyle,
    this.query,
    this.targetLineNumber,
    this.ttsHighlightStart,
    this.ttsHighlightEnd,
    this.onSelectionChanged,
    this.onContextMenu,
    this.columnSpacing = 8.0,
    this.bookmarkLineNumbers = const [],
    this.onPageLineChanged,
    this.markedWords = const {},
    this.onMarkEnter,
    this.onMarkExit,
    this.onHoverHideRequest,
  }) : assert(columnSpacing >= 0);

  final List<TextSegment> segments;
  final TextStyle? baseStyle;
  final String? query;
  final int? targetLineNumber;
  final int? ttsHighlightStart;
  final int? ttsHighlightEnd;
  final ValueChanged<String?>? onSelectionChanged;
  final void Function(Offset position, String selectedText)? onContextMenu;
  final double columnSpacing;
  final List<int> bookmarkLineNumbers;
  final ValueChanged<int>? onPageLineChanged;
  final Map<String, MarkStyle> markedWords;
  final void Function(String word, Offset globalPosition, HoverToken token)?
      onMarkEnter;
  final void Function(HoverToken token)? onMarkExit;

  /// Fired when the viewer-level hover state should be dropped wholesale —
  /// page turn, selection drag started, etc.
  final VoidCallback? onHoverHideRequest;

  @override
  ConsumerState<VerticalTextViewer> createState() =>
      _VerticalTextViewerState();
}

// Layout constants
const _kHorizontalPadding = 32.0;
const _kVerticalPadding = 62.0;
const _kTextHeight = 1.1;
const _kDefaultFontSize = 14.0;

// Page transition animation constants
const _kPageTransitionDuration = Duration(milliseconds: 250);
const _kPageTransitionCurve = Curves.easeInOut;

// Two-step file-navigation confirmation window. After the user attempts to
// cross a file boundary the prompt is shown for this long; a second
// same-direction press within the window confirms the switch.
const _kFileNavigationPromptTimeout = Duration(seconds: 4);

// Minimum delay between showing the prompt and accepting a confirming press.
// Without this, holding an arrow key (KeyRepeatEvent) or rapidly spinning
// the mouse wheel would auto-confirm the file switch on the very next tick.
const _kFileNavigationConfirmCooldown = Duration(milliseconds: 300);

class _VerticalTextViewerState extends ConsumerState<VerticalTextViewer>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  int _pageCount = 1;
  int _lastReportedLine = 0;
  final FocusNode _focusNode = FocusNode();

  // Two-step file boundary navigation state. Only one direction can be
  // pending at a time; switching direction (or any unrelated input) cancels
  // the pending prompt.
  bool _pendingNextFilePrompt = false;
  bool _pendingPrevFilePrompt = false;
  Timer? _promptTimeoutTimer;
  // While true, additional boundary inputs are ignored even if a prompt is
  // pending — prevents KeyRepeat / wheel bursts from auto-confirming.
  bool _inConfirmCooldown = false;
  Timer? _confirmCooldownTimer;

  // True when the next non-null `pendingFileEntryIntent` should still be
  // consumed by this viewer's first build. Cleared after consumption to
  // guarantee the one-shot semantics of the intent provider.
  bool _intentAlreadyConsumed = false;
  // Captures the desired initial page (last page) when the consumed intent
  // was `fromEnd`. Applied via post-frame once `_pageCount` is known.
  bool _jumpToLastPagePending = false;

  // Split segments into lines for pagination
  List<List<TextSegment>> _lines = [];

  // Cache TextPainter for character metrics
  TextPainter? _cachedPainter;
  TextStyle? _cachedStyle;

  // F115: memoized "heavy" pagination layer (full-document column/page layout).
  // Keyed by (segments identity, constraints, style, columnSpacing). The light
  // layer (targetPage / bookmarkPages / firstLinePerPage) is derived from this
  // on every build, so bookmark/target changes never invalidate it.
  _HeavyPagination? _cachedHeavy;
  List<TextSegment>? _cachedHeavySegments;
  BoxConstraints? _cachedHeavyConstraints;
  TextStyle? _cachedHeavyStyle;
  double? _cachedHeavyColumnSpacing;

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
    _consumePendingIntent();
  }

  void _consumePendingIntent() {
    if (_intentAlreadyConsumed) return;
    final intent = ref.read(pendingFileEntryIntentProvider);
    if (intent == null) return;
    _intentAlreadyConsumed = true;
    if (intent == FileEntryStartIntent.fromEnd) {
      _jumpToLastPagePending = true;
    }
    // Riverpod 3.x rejects provider mutations during a widget life-cycle
    // (initState / didUpdateWidget). Defer the one-shot clear to a
    // microtask so it runs after the current build settles.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(pendingFileEntryIntentProvider.notifier).clear();
    });
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
      // A new segments stream means the file changed: drop any pending
      // boundary prompt to avoid carrying it across files.
      _clearPendingPrompts();
      // Allow consuming a fresh intent (e.g., the navigation that drove the
      // file switch).
      _intentAlreadyConsumed = false;
      _consumePendingIntent();
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

  /// Page index for which a target-line auto-jump postFrame callback is
  /// currently in flight. Prevents the same jump from being scheduled
  /// multiple times when `build()` re-runs before the post-frame fires.
  int? _scheduledTargetPage;

  @override
  void dispose() {
    _promptTimeoutTimer?.cancel();
    _confirmCooldownTimer?.cancel();
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
    // Page navigation is scoped to this viewer (not HomeScreen's global
    // Shortcuts) so the arrow keys only page while the viewer holds focus, and
    // never steal arrow-key focus traversal from the file browser. The vertical
    // viewer translates the logical next/prev into its physical direction:
    // left = next (right-to-left reading), right = previous.
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowLeft): NextPageIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): PrevPageIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NextPageIntent: CallbackAction<NextPageIntent>(
            onInvoke: (_) {
              _nextPage();
              return null;
            },
          ),
          PrevPageIntent: CallbackAction<PrevPageIntent>(
            onInvoke: (_) {
              _previousPage();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
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

            // Resolve every layout-derived side effect as a pure decision over
            // an immutable snapshot, then apply them in one place
            // (_applyViewerEffects). This keeps build() free of the scattered
            // in-layout flag mutations and post-frame schedulers it used to
            // orchestrate inline (F156).
            final constraintsChanged = _lastConstraints != constraints;
            final effects = resolveViewerEffects(ViewerEffectInputs(
              totalPages: totalPages,
              currentPage: _currentPage,
              targetPage: result.targetPage,
              scheduledTargetPage: _scheduledTargetPage,
              jumpToLastPagePending: _jumpToLastPagePending,
              pendingTtsOffset: _pendingTtsOffset,
              charOffsetPerPage: result.charOffsetPerPage,
              firstLinePerPage: result.firstLinePerPage,
              lastReportedLine: _lastReportedLine,
              constraintsChanged: constraintsChanged,
              isAnimating: _animationController.isAnimating,
            ));
            _applyViewerEffects(effects);

            _lastConstraints = constraints;

            final safePage = totalPages == 0
                ? 0
                : _currentPage.clamp(0, totalPages - 1);

            final currentSegments =
                totalPages > 0 ? pages[safePage] : <TextSegment>[];
            _currentPageSegments = currentSegments;

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
                onContextMenu: widget.onContextMenu,
                onSwipe: _handleSwipe,
                columnSpacing: widget.columnSpacing,
                markedWords: widget.markedWords,
                onMarkEnter: widget.onMarkEnter,
                onMarkExit: widget.onMarkExit,
                onHoverHideRequest: widget.onHoverHideRequest,
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
                        markedWords: widget.markedWords,
                        // Symmetric wiring with the incoming page: if the
                        // pointer briefly hovers the outgoing page during
                        // the slide animation, callbacks still route to
                        // the notifier so no orphan token leaks.
                        onMarkEnter: widget.onMarkEnter,
                        onMarkExit: widget.onMarkExit,
                        onHoverHideRequest: widget.onHoverHideRequest,
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

            final hasBookmarkOnPage = result.bookmarkPages.contains(safePage);

            return Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: pageContent,
                        ),
                      ),
                      if (hasBookmarkOnPage)
                        const Positioned(
                          left: 4,
                          top: 4,
                          child: Icon(Icons.bookmark, color: Colors.orange, size: 20),
                        ),
                    ],
                  ),
                ),
                if (totalPages > 1 ||
                    _pendingNextFilePrompt ||
                    _pendingPrevFilePrompt)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _buildIndicatorText(context, safePage + 1, totalPages),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            );
          },
            ),
          ),
        ),
      ),
    );
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
    if (newPage == _currentPage) {
      // The page index is pinned at the boundary. Re-route the input through
      // the file-boundary handler which decides whether to surface the
      // 2-step "go to next/previous episode" prompt or confirm a pending
      // one.
      _handleBoundaryNavigation(delta);
      return;
    }

    // Any successful in-file page move cancels a pending boundary prompt.
    _clearPendingPrompts();

    setState(() {
      _outgoingSegments = _currentPageSegments;
      _slideDirection = delta.sign;
      _currentPage = newPage;
    });

    _animationController
      ..reset()
      ..forward();
    widget.onSelectionChanged?.call(null);
    widget.onHoverHideRequest?.call();
  }

  /// Resolves a page-turn input that hit a file boundary (first or last page).
  /// Surfaces the prompt on the first press, confirms file switch on the
  /// second press within the timeout, and ignores both when there is no
  /// adjacent file in the directory.
  void _handleBoundaryNavigation(int delta) {
    if (delta == 0) return;
    final adjacent = ref.read(adjacentFilesProvider);
    if (delta > 0) {
      // "Next page" at the last page → next episode candidate.
      if (adjacent.next == null) return;
      if (_pendingNextFilePrompt) {
        if (_inConfirmCooldown) return;
        _confirmFileNavigation(
            ref.read(episodeNavigationControllerProvider).navigateToNext);
      } else {
        _showFileNavigationPrompt(next: true);
      }
    } else {
      // "Previous page" at the first page → previous episode candidate.
      if (adjacent.prev == null) return;
      if (_pendingPrevFilePrompt) {
        if (_inConfirmCooldown) return;
        _confirmFileNavigation(
            ref.read(episodeNavigationControllerProvider).navigateToPrevious);
      } else {
        _showFileNavigationPrompt(next: false);
      }
    }
  }

  /// Runs the actual file swap after a confirming second press. Beyond
  /// clearing the prompt, this also drops any in-flight text selection and
  /// hover popup — the new file has different content and the anchor
  /// coordinates from the prior episode would otherwise leak visually into
  /// the new page.
  void _confirmFileNavigation(VoidCallback navigate) {
    _clearPendingPrompts();
    widget.onSelectionChanged?.call(null);
    widget.onHoverHideRequest?.call();
    navigate();
  }

  void _showFileNavigationPrompt({required bool next}) {
    _promptTimeoutTimer?.cancel();
    _confirmCooldownTimer?.cancel();
    _inConfirmCooldown = true;
    _confirmCooldownTimer =
        Timer(_kFileNavigationConfirmCooldown, () {
      _inConfirmCooldown = false;
    });
    setState(() {
      _pendingNextFilePrompt = next;
      _pendingPrevFilePrompt = !next;
    });
    _promptTimeoutTimer =
        Timer(_kFileNavigationPromptTimeout, _clearPendingPrompts);
  }

  void _clearPendingPrompts() {
    _promptTimeoutTimer?.cancel();
    _promptTimeoutTimer = null;
    _confirmCooldownTimer?.cancel();
    _confirmCooldownTimer = null;
    _inConfirmCooldown = false;
    if (!_pendingNextFilePrompt && !_pendingPrevFilePrompt) return;
    setState(() {
      _pendingNextFilePrompt = false;
      _pendingPrevFilePrompt = false;
    });
  }

  void _nextPage() => _changePage(1);
  void _previousPage() => _changePage(-1);

  String _buildIndicatorText(BuildContext context, int currentPage, int total) {
    final l10n = AppLocalizations.of(context)!;
    if (_pendingNextFilePrompt) {
      final name = ref.read(adjacentFilesProvider).next?.name;
      if (name != null) {
        return l10n.verticalText_nextEpisodePrompt(name);
      }
    }
    if (_pendingPrevFilePrompt) {
      final name = ref.read(adjacentFilesProvider).prev?.name;
      if (name != null) {
        return l10n.verticalText_prevEpisodePrompt(name);
      }
    }
    return '$currentPage / $total';
  }

  void _goToPage(int page) =>
      _changePage(page - _currentPage);

  /// Applies the [ViewerEffects] decided by [resolveViewerEffects].
  ///
  /// Synchronous updates (animation cancel, scheduled-target guard, one-shot
  /// flag consumption, reported-line record) happen immediately so a rebuild
  /// before the post-frame fires cannot apply a one-shot effect twice. The
  /// page jumps, hover-hide and line callback are deferred to a single
  /// post-frame callback.
  void _applyViewerEffects(ViewerEffects effects) {
    // ② Cancel an in-flight animation on layout change (immediate, as before).
    if (effects.cancelAnimation) {
      _animationController.stop();
      _outgoingSegments = null;
    }
    // ① Record the scheduled target page synchronously so the re-entrancy
    // guard in resolveViewerEffects sees it on the next build.
    if (effects.newScheduledTargetPage != null) {
      _scheduledTargetPage = effects.newScheduledTargetPage;
    }
    // ③/④ Consume one-shot triggers synchronously.
    if (effects.consumeJumpToLastPage) {
      _jumpToLastPagePending = false;
    }
    if (effects.consumeTtsOffset) {
      _pendingTtsOffset = null;
    }
    // ⑤ Record the reported line synchronously (guards duplicate reports).
    if (effects.reportLine != null) {
      _lastReportedLine = effects.reportLine!;
    }

    final hasPostFrameWork = effects.targetJumpToPage != null ||
        effects.lastJumpToPage != null ||
        effects.animatedGoToPage != null ||
        effects.reportLine != null;
    if (!hasPostFrameWork) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // ① reset the re-entrancy guard once the scheduled frame runs.
      if (effects.newScheduledTargetPage != null) {
        _scheduledTargetPage = null;
      }

      // ① Target-line jump (no slide animation). Re-checks the page hasn't
      // already moved, clears the target line, and drops the now-stale hover
      // popup (the jump bypasses _changePage). Skipping the hover-hide when the
      // jump is a no-op matches the prior code, which returned early.
      final targetJump = effects.targetJumpToPage;
      if (targetJump != null && targetJump != _currentPage) {
        setState(() {
          _currentPage = targetJump;
          _targetLine = null;
        });
        widget.onHoverHideRequest?.call();
      }

      // ③ Last-page (`fromEnd`) jump. Applied unconditionally as before, after
      // ① so it wins when both fire in the same build.
      final lastJump = effects.lastJumpToPage;
      if (lastJump != null) {
        setState(() {
          _currentPage = lastJump;
        });
        widget.onHoverHideRequest?.call();
      }

      // ④ TTS animated navigation via _changePage (which also hides hover).
      if (effects.animatedGoToPage != null) {
        _goToPage(effects.animatedGoToPage!);
      }

      // ⑤ Report the current page's first line number.
      if (effects.reportLine != null) {
        widget.onPageLineChanged?.call(effects.reportLine!);
      }
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
      return _PaginationResult([widget.segments], null, const [0], const [{}], const {}, const [1]);
    }

    final heavy = _heavyPagination(
      constraints: constraints,
      style: style,
      charWidth: charWidth,
      charsPerColumn: charsPerColumn,
      availableWidth: availableWidth,
    );

    if (heavy == null) {
      return _PaginationResult([widget.segments], null, const [0], const [{}], const {}, const [1]);
    }

    final pages = heavy.pages;
    final pageStarts = heavy.pageStarts;
    final lineStartColumns = heavy.lineStartColumns;

    // --- Light layer ---
    // Cheap, O(pages) derivations recomputed on every build from the cached
    // heavy layer. Their inputs (target line, bookmark line set) change
    // independently of the document layout, so keeping them out of the cache
    // means a bookmark add or target-line jump never re-paginates.
    final targetPage =
        _findTargetPage(lineStartColumns, pageStarts, pages.length);

    // Compute which pages have bookmarks
    final bookmarkPages = <int>{};
    for (final lineNum in widget.bookmarkLineNumbers) {
      final lineIndex = (lineNum - 1).clamp(0, _lines.length - 1);
      if (lineIndex < lineStartColumns.length) {
        final colIndex = lineStartColumns[lineIndex];
        for (var i = pageStarts.length - 1; i >= 0; i--) {
          if (colIndex >= pageStarts[i]) {
            if (i < pages.length) bookmarkPages.add(i);
            break;
          }
        }
      }
    }

    // Compute first line number for each page
    final firstLinePerPage = <int>[];
    for (final startCol in pageStarts) {
      var lineNum = 1; // default to first line
      for (var i = lineStartColumns.length - 1; i >= 0; i--) {
        if (lineStartColumns[i] <= startCol) {
          lineNum = i + 1; // 1-based line number
          break;
        }
      }
      firstLinePerPage.add(lineNum);
    }

    return _PaginationResult(pages, targetPage, heavy.charOffsetPerPage,
        heavy.lineBreakIndicesPerPage, bookmarkPages, firstLinePerPage);
  }

  /// Expensive, full-document pagination layer (column splitting, kinsoku line
  /// breaking, page grouping, per-page char offsets). Memoized by
  /// (segments identity, constraints, style, columnSpacing); on a cache hit the
  /// previous result is returned untouched and [verticalPaginationHeavyCount]
  /// does NOT increment. Returns null when the layout produces no pages
  /// (degenerate constraints), which is not cached so the next build retries.
  _HeavyPagination? _heavyPagination({
    required BoxConstraints constraints,
    required TextStyle style,
    required double charWidth,
    required int charsPerColumn,
    required double availableWidth,
  }) {
    final cached = _cachedHeavy;
    if (cached != null &&
        identical(_cachedHeavySegments, widget.segments) &&
        _cachedHeavyConstraints == constraints &&
        _cachedHeavyStyle == style &&
        _cachedHeavyColumnSpacing == widget.columnSpacing) {
      return cached;
    }

    verticalPaginationHeavyCount++;
    final columns = <List<TextSegment>>[];
    final lineStartColumns = _buildColumns(charsPerColumn, columns);
    final lineStartSet = lineStartColumns.skip(1).toSet();
    final (pages, pageStarts, lineBreakIndicesPerPage) =
        _groupColumnsIntoPages(columns, charWidth, availableWidth, lineStartSet);

    if (pages.isEmpty) return null;

    final charOffsetPerPage =
        computeCharOffsetPerPage(columns, pageStarts, lineStartColumns);

    final heavy = _HeavyPagination(
      pages: pages,
      pageStarts: pageStarts,
      lineBreakIndicesPerPage: lineBreakIndicesPerPage,
      charOffsetPerPage: charOffsetPerPage,
      lineStartColumns: lineStartColumns,
    );
    _cachedHeavy = heavy;
    _cachedHeavySegments = widget.segments;
    _cachedHeavyConstraints = constraints;
    _cachedHeavyStyle = style;
    _cachedHeavyColumnSpacing = widget.columnSpacing;
    return heavy;
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

/// The memoized "heavy" pagination layer: everything that depends only on the
/// document, the layout constraints, the text style, and the column spacing.
/// Deliberately excludes targetPage / bookmarkPages / firstLinePerPage, which
/// depend on inputs that change independently of the layout (see [_paginateLines]).
class _HeavyPagination {
  const _HeavyPagination({
    required this.pages,
    required this.pageStarts,
    required this.lineBreakIndicesPerPage,
    required this.charOffsetPerPage,
    required this.lineStartColumns,
  });

  final List<List<TextSegment>> pages;
  final List<int> pageStarts;
  final List<Set<int>> lineBreakIndicesPerPage;
  final List<int> charOffsetPerPage;
  final List<int> lineStartColumns;
}

class _PaginationResult {
  const _PaginationResult(this.pages, this.targetPage, this.charOffsetPerPage, this.lineBreakIndicesPerPage, this.bookmarkPages, this.firstLinePerPage);
  final List<List<TextSegment>> pages;
  final int? targetPage;
  final List<int> charOffsetPerPage;
  final List<Set<int>> lineBreakIndicesPerPage;
  final Set<int> bookmarkPages;
  final List<int> firstLinePerPage;
}
