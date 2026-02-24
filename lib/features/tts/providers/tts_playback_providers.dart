import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/tts_adapters.dart';
import '../data/tts_isolate.dart';
import '../data/tts_playback_controller.dart';

/// Factory function type for creating [TtsPlaybackController] instances.
typedef TtsControllerFactory = Future<TtsPlaybackController> Function(
  ProviderContainer container,
);

/// Provider for [TtsControllerFactory], enabling test overrides.
final ttsControllerFactoryProvider = Provider<TtsControllerFactory>(
  (ref) => _defaultControllerFactory,
);

Future<TtsPlaybackController> _defaultControllerFactory(
  ProviderContainer container,
) async {
  final tempDir = await getTemporaryDirectory();
  return TtsPlaybackController(
    ref: container,
    ttsIsolate: TtsIsolate(),
    audioPlayer: JustAudioPlayer(),
    wavWriter: WavWriterAdapter(),
    fileCleaner: FileCleanerImpl(),
    tempDirPath: tempDir.path,
  );
}

enum TtsPlaybackState { stopped, loading, playing, paused }

final ttsPlaybackStateProvider =
    NotifierProvider<TtsPlaybackStateNotifier, TtsPlaybackState>(
  TtsPlaybackStateNotifier.new,
);

class TtsPlaybackStateNotifier extends Notifier<TtsPlaybackState> {
  @override
  TtsPlaybackState build() => TtsPlaybackState.stopped;

  void set(TtsPlaybackState value) => state = value;
}

final ttsHighlightRangeProvider =
    NotifierProvider<TtsHighlightRangeNotifier, TextRange?>(
  TtsHighlightRangeNotifier.new,
);

class TtsHighlightRangeNotifier extends Notifier<TextRange?> {
  @override
  TextRange? build() => null;

  void set(TextRange? value) => state = value;
}
