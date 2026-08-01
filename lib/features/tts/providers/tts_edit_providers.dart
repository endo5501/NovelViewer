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

// --- Playhead ---

/// The segment the next playback starts from.
///
/// Moved by tapping a row, by playback advancing, and by playback reaching the
/// end (which returns it to the first segment). Never null: an unset playhead
/// would only add a state the UI has to explain, and "at the first segment" is
/// exactly the old "play all" behaviour.
final ttsEditCursorIndexProvider =
    NotifierProvider<TtsEditCursorIndexNotifier, int>(
  TtsEditCursorIndexNotifier.new,
);

class TtsEditCursorIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

// --- Edit playback state ---

/// Whether preview playback is currently running. The position it is at lives
/// in [ttsEditCursorIndexProvider].
final ttsEditPlayingProvider =
    NotifierProvider<TtsEditPlayingNotifier, bool>(
  TtsEditPlayingNotifier.new,
);

class TtsEditPlayingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}
