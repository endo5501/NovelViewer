import 'package:flutter/material.dart';

import '../data/tts_dictionary_repository.dart';
import '../data/tts_edit_segment.dart';
import 'tts_edit_segment_row.dart';

/// The scrollable segment list of the TTS edit dialog.
///
/// Takes plain data and callbacks rather than reading providers, so it can be
/// pumped on its own — the dialog around it grabs a real database, a real TTS
/// isolate and a real audio player in `initState` and cannot.
class TtsEditSegmentList extends StatelessWidget {
  const TtsEditSegmentList({
    super.key,
    required this.segments,
    required this.isGenerating,
    required this.generatingIndex,
    required this.playbackIndex,
    required this.voiceFiles,
    required this.onTextEditComplete,
    required this.onRefWavPathChanged,
    required this.onMemoEditComplete,
    required this.onPlay,
    required this.onGenerate,
    required this.onReset,
    this.dictRepository,
  });

  final List<TtsEditSegment> segments;

  /// True while bulk or single generation is running. Disables row actions.
  final bool isGenerating;

  /// Index of the segment being generated, or null when none is.
  final int? generatingIndex;

  /// Index of the segment being played, or null when nothing is playing.
  final int? playbackIndex;

  final List<String> voiceFiles;
  final TtsDictionaryRepository? dictRepository;

  final void Function(int index, String text) onTextEditComplete;
  final void Function(int index, String? value) onRefWavPathChanged;
  final void Function(int index, String? memo) onMemoEditComplete;
  final void Function(int index) onPlay;
  final void Function(int index) onGenerate;
  final void Function(int index) onReset;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: segments.length,
      itemBuilder: (context, index) {
        return TtsEditSegmentRow(
          segment: segments[index],
          isGenerating: isGenerating && generatingIndex == index,
          isPlaying: playbackIndex == index,
          voiceFiles: voiceFiles,
          onTextEditComplete: (text) => onTextEditComplete(index, text),
          onRefWavPathChanged: (value) => onRefWavPathChanged(index, value),
          onMemoEditComplete: (memo) => onMemoEditComplete(index, memo),
          onPlay: () => onPlay(index),
          onGenerate: () => onGenerate(index),
          onReset: () => onReset(index),
          // Wired up when the list starts owning the playhead.
          isCursor: false,
          onCursorRequested: () {},
          enabled: !isGenerating,
          dictRepository: dictRepository,
        );
      },
    );
  }
}
