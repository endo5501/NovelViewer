import 'package:flutter/material.dart';

import '../data/tts_dictionary_repository.dart';
import '../data/tts_edit_segment.dart';
import 'tts_edit_segment_row.dart';

/// The scrollable segment list of the TTS edit dialog.
///
/// Owns the presentation side of the playhead: it decides whether a row's
/// request to take it is honoured, and keeps the row holding it in view.
///
/// Takes plain data and callbacks rather than reading providers, so it can be
/// pumped on its own — the dialog around it grabs a real database, a real TTS
/// isolate and a real audio player in `initState` and cannot.
class TtsEditSegmentList extends StatefulWidget {
  const TtsEditSegmentList({
    super.key,
    required this.segments,
    required this.isGenerating,
    required this.generatingIndex,
    required this.isPlaying,
    required this.cursorIndex,
    required this.voiceFiles,
    required this.onTextEditComplete,
    required this.onRefWavPathChanged,
    required this.onMemoEditComplete,
    required this.onPlay,
    required this.onGenerate,
    required this.onReset,
    required this.onSkipToggled,
    required this.onCursorChanged,
    this.dictRepository,
  });

  final List<TtsEditSegment> segments;

  /// True while bulk or single generation is running. Disables row actions.
  final bool isGenerating;

  /// Index of the segment being generated, or null when none is.
  final int? generatingIndex;

  /// True while preview playback is running.
  final bool isPlaying;

  /// The segment the next playback starts from.
  final int cursorIndex;

  final List<String> voiceFiles;
  final TtsDictionaryRepository? dictRepository;

  final void Function(int index, String text) onTextEditComplete;
  final void Function(int index, String? value) onRefWavPathChanged;
  final void Function(int index, String? memo) onMemoEditComplete;
  final void Function(int index) onPlay;
  final void Function(int index) onGenerate;
  final void Function(int index) onReset;
  final void Function(int index) onSkipToggled;
  final void Function(int index) onCursorChanged;

  @override
  State<TtsEditSegmentList> createState() => _TtsEditSegmentListState();
}

class _TtsEditSegmentListState extends State<TtsEditSegmentList> {
  final _scrollController = ScrollController();

  /// One key per index, kept for the list's lifetime. Moving a single key onto
  /// whichever row holds the playhead would reparent that element and drag the
  /// row's text controllers along with it.
  final _rowKeys = <int, GlobalKey>{};

  @override
  void didUpdateWidget(TtsEditSegmentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cursorIndex != oldWidget.cursorIndex) {
      _revealCursor(movingForward: widget.cursorIndex > oldWidget.cursorIndex);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Brings the playhead row into view, and only then — a row already on screen
  /// stays where it is, so a user reading elsewhere during playback is not
  /// yanked back every segment.
  void _revealCursor({required bool movingForward}) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(movingForward: movingForward, mayApproach: true),
    );
  }

  void _reveal({required bool movingForward, required bool mayApproach}) {
    if (!mounted) return;

    final context = _rowKeys[widget.cursorIndex]?.currentContext;
    if (context == null) {
      // The row is too far outside the viewport for ListView to have built it,
      // so there is no element to reveal. Jump to where it should roughly be
      // and correct on the next frame, once it exists. Without this the list
      // would stop following the playhead for the rest of the run, since every
      // later advance would find nothing built either.
      if (!mayApproach || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_estimatedOffsetOfCursor());
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reveal(movingForward: movingForward, mayApproach: false),
      );
      return;
    }

    // These two policies clamp the scroll to one direction, which is what
    // makes an already-visible row a no-op: the computed target equals the
    // current offset, and ensureVisible does nothing.
    Scrollable.ensureVisible(
      context,
      alignmentPolicy: movingForward
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  /// Where the playhead row would be if every row were the same height. Only
  /// an approximation — rows grow with wrapped text — so it is always followed
  /// by an [Scrollable.ensureVisible] that lands it exactly.
  double _estimatedOffsetOfCursor() {
    final position = _scrollController.position;
    final lastIndex = widget.segments.length - 1;
    if (lastIndex <= 0) return position.minScrollExtent;
    final fraction = (widget.cursorIndex / lastIndex).clamp(0.0, 1.0);
    return position.minScrollExtent +
        (position.maxScrollExtent - position.minScrollExtent) * fraction;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.segments.length,
      itemBuilder: (context, index) {
        return KeyedSubtree(
          key: _rowKeys.putIfAbsent(index, GlobalKey.new),
          child: TtsEditSegmentRow(
            segment: widget.segments[index],
            isGenerating: widget.isGenerating && widget.generatingIndex == index,
            isPlaying: widget.isPlaying && widget.cursorIndex == index,
            isCursor: widget.cursorIndex == index,
            voiceFiles: widget.voiceFiles,
            onTextEditComplete: (text) => widget.onTextEditComplete(index, text),
            onRefWavPathChanged: (value) =>
                widget.onRefWavPathChanged(index, value),
            onMemoEditComplete: (memo) => widget.onMemoEditComplete(index, memo),
            onPlay: () => widget.onPlay(index),
            onGenerate: () => widget.onGenerate(index),
            onReset: () => widget.onReset(index),
            onSkipToggled: () => widget.onSkipToggled(index),
            // Playback owns the playhead while it runs: two writers would fight
            // over the value and the highlight would jump between them.
            onCursorRequested: () {
              if (!widget.isPlaying) widget.onCursorChanged(index);
            },
            // Also off during playback: a row's play button reports playback
            // finished when its own segment ends, which would release the
            // playhead lock while the run it interrupted is still going.
            enabled: !widget.isGenerating && !widget.isPlaying,
            dictRepository: widget.dictRepository,
          ),
        );
      },
    );
  }
}
