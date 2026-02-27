import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tts_edit_segment.dart';

// --- Edit segment list state ---

final ttsEditSegmentsProvider =
    NotifierProvider<TtsEditSegmentsNotifier, List<TtsEditSegment>>(
  TtsEditSegmentsNotifier.new,
);

class TtsEditSegmentsNotifier extends Notifier<List<TtsEditSegment>> {
  @override
  List<TtsEditSegment> build() => [];

  void set(List<TtsEditSegment> segments) => state = segments;

  void updateSegment(int index, TtsEditSegment segment) {
    state = [
      ...state.sublist(0, index),
      segment,
      ...state.sublist(index + 1),
    ];
  }

  void refresh() {
    state = [...state];
  }
}

// --- Edit generation state ---

enum TtsEditGenerationState { idle, generating }

final ttsEditGenerationStateProvider =
    NotifierProvider<TtsEditGenerationStateNotifier, TtsEditGenerationState>(
  TtsEditGenerationStateNotifier.new,
);

class TtsEditGenerationStateNotifier extends Notifier<TtsEditGenerationState> {
  @override
  TtsEditGenerationState build() => TtsEditGenerationState.idle;

  void set(TtsEditGenerationState value) => state = value;
}

// --- Index of currently generating segment ---

final ttsEditGeneratingIndexProvider =
    NotifierProvider<TtsEditGeneratingIndexNotifier, int?>(
  TtsEditGeneratingIndexNotifier.new,
);

class TtsEditGeneratingIndexNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? value) => state = value;
}

// --- Edit playback state ---

final ttsEditPlaybackIndexProvider =
    NotifierProvider<TtsEditPlaybackIndexNotifier, int?>(
  TtsEditPlaybackIndexNotifier.new,
);

class TtsEditPlaybackIndexNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? value) => state = value;
}
