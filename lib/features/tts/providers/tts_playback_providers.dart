import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TtsPlaybackState { stopped, loading, playing }

final ttsPlaybackStateProvider =
    NotifierProvider<TtsPlaybackStateNotifier, TtsPlaybackState>(
  TtsPlaybackStateNotifier.new,
);

class TtsPlaybackStateNotifier extends Notifier<TtsPlaybackState> {
  @override
  TtsPlaybackState build() => TtsPlaybackState.stopped;

  // ignore: use_setters_to_change_properties
  void set(TtsPlaybackState value) {
    state = value;
  }
}

final ttsHighlightRangeProvider =
    NotifierProvider<TtsHighlightRangeNotifier, TextRange?>(
  TtsHighlightRangeNotifier.new,
);

class TtsHighlightRangeNotifier extends Notifier<TextRange?> {
  @override
  TextRange? build() => null;

  // ignore: use_setters_to_change_properties
  void set(TextRange? value) {
    state = value;
  }
}
