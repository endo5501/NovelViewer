import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Audio generation state ---

enum TtsAudioState { none, generating, ready }

final ttsAudioStateProvider =
    NotifierProvider<TtsAudioStateNotifier, TtsAudioState>(
  TtsAudioStateNotifier.new,
);

class TtsAudioStateNotifier extends Notifier<TtsAudioState> {
  @override
  TtsAudioState build() => TtsAudioState.none;

  void set(TtsAudioState value) => state = value;
}

// --- Generation progress ---

class TtsGenerationProgress {
  const TtsGenerationProgress({required this.current, required this.total});
  final int current;
  final int total;

  static const zero = TtsGenerationProgress(current: 0, total: 0);
}

final ttsGenerationProgressProvider =
    NotifierProvider<TtsGenerationProgressNotifier, TtsGenerationProgress>(
  TtsGenerationProgressNotifier.new,
);

class TtsGenerationProgressNotifier extends Notifier<TtsGenerationProgress> {
  @override
  TtsGenerationProgress build() => TtsGenerationProgress.zero;

  void set(TtsGenerationProgress value) => state = value;
}

// --- Playback state ---

enum TtsPlaybackState { stopped, playing, paused, waiting }

final ttsPlaybackStateProvider =
    NotifierProvider<TtsPlaybackStateNotifier, TtsPlaybackState>(
  TtsPlaybackStateNotifier.new,
);

class TtsPlaybackStateNotifier extends Notifier<TtsPlaybackState> {
  @override
  TtsPlaybackState build() => TtsPlaybackState.stopped;

  void set(TtsPlaybackState value) => state = value;
}

// --- Highlight range ---

final ttsHighlightRangeProvider =
    NotifierProvider<TtsHighlightRangeNotifier, TextRange?>(
  TtsHighlightRangeNotifier.new,
);

class TtsHighlightRangeNotifier extends Notifier<TextRange?> {
  @override
  TextRange? build() => null;

  void set(TextRange? value) => state = value;
}
