import 'dart:async';

import 'tts_playback_controller.dart';

/// Plays one TTS segment via the underlying [TtsAudioPlayer].
///
/// **Order is load-bearing — do not "simplify" without reading this:**
/// 1. `setFilePath()` is called BEFORE `playerStateStream.listen()`. The
///    stream is a `BehaviorSubject` that replays the last `completed` state
///    — listening first would immediately fire and skip the next segment.
///    `setFilePath` resets `processingState` to `ready`, which is what we
///    want to observe.
/// 2. `play()` is fire-and-forget (`unawaited` + `catchError`). Completion is
///    signalled by `playerStateStream`, **not** by awaiting `play()`.
/// 3. After `completed`, we call `pause()` rather than `stop()` for
///    intermediate segments. `stop()` destroys the platform player
///    (MediaKitPlayer) and kills any audio still in the WASAPI output buffer
///    — the tail of the current segment would be cut off.
/// 4. On the LAST segment we wait [bufferDrainDelay] before returning so the
///    OS has time to drain its output buffer (otherwise the tail of the
///    audio is lost). This delay also runs between intermediate segments,
///    but the drain is shorter / less noticeable; a single value covers both.
class SegmentPlayer {
  SegmentPlayer({
    required TtsAudioPlayer player,
    this.bufferDrainDelay = const Duration(milliseconds: 500),
  }) : _player = player;

  final TtsAudioPlayer _player;
  final Duration bufferDrainDelay;

  bool _stopped = false;
  Completer<void>? _activeDrainSignal;
  Completer<void>? _activePlayCompleter;

  /// Plays [filePath] and resolves once the segment has finished playing
  /// AND the audio output buffer has drained. Throws if the underlying
  /// player throws synchronously or via `play().catchError`.
  Future<void> playSegment(String filePath, {required bool isLast}) async {
    if (_stopped) return;

    // (1) setFilePath BEFORE listen — see class doc.
    await _player.setFilePath(filePath);

    final playCompleter = Completer<void>();
    _activePlayCompleter = playCompleter;
    late StreamSubscription<TtsPlayerState> sub;
    sub = _player.playerStateStream.listen((state) {
      if (state == TtsPlayerState.completed && !playCompleter.isCompleted) {
        playCompleter.complete();
      }
    });

    // (2) Fire-and-forget play; route any exceptions into the completer so
    //     callers see them as a Future error from playSegment.
    unawaited(_player.play().catchError((Object e, StackTrace st) {
      if (!playCompleter.isCompleted) playCompleter.completeError(e, st);
    }));

    try {
      await playCompleter.future;
    } finally {
      _activePlayCompleter = null;
      await sub.cancel();
    }

    // (4) Drain delay — abortable via stop().
    if (bufferDrainDelay > Duration.zero) {
      final drainSignal = Completer<void>();
      _activeDrainSignal = drainSignal;
      try {
        await Future.any([
          Future<void>.delayed(bufferDrainDelay),
          drainSignal.future,
        ]);
      } finally {
        _activeDrainSignal = null;
      }
    }

    if (_stopped) return;

    // (3) pause() between segments — NOT stop().
    if (!isLast) {
      await _player.pause();
    }
  }

  /// User-initiated stop. Skips any pending drain delay and prevents further
  /// pause/stop calls from this segment.
  Future<void> stop() async {
    _stopped = true;
    _releasePending();
    await _player.stop();
  }

  Future<void> dispose() async {
    _stopped = true;
    _releasePending();
    await _player.dispose();
  }

  void _releasePending() {
    final drain = _activeDrainSignal;
    if (drain != null && !drain.isCompleted) {
      drain.complete();
    }
    _activeDrainSignal = null;
    final play = _activePlayCompleter;
    if (play != null && !play.isCompleted) {
      play.complete();
    }
    _activePlayCompleter = null;
  }
}
