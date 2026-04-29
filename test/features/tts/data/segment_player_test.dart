import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/segment_player.dart';
import 'package:novel_viewer/features/tts/data/tts_playback_controller.dart';

/// Records every method call so tests can assert call order and counts.
class _RecordingAudioPlayer implements TtsAudioPlayer {
  final _stateController = StreamController<TtsPlayerState>.broadcast();
  final calls = <String>[];
  bool isDisposed = false;
  bool autoComplete = false;

  @override
  Stream<TtsPlayerState> get playerStateStream {
    calls.add('listen');
    return _stateController.stream;
  }

  @override
  Future<void> setFilePath(String path) async {
    calls.add('setFilePath:$path');
  }

  @override
  Future<void> play() async {
    calls.add('play');
    if (autoComplete) {
      Future.microtask(() {
        if (!_stateController.isClosed) {
          _stateController.add(TtsPlayerState.completed);
        }
      });
    }
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    isDisposed = true;
    await _stateController.close();
  }

  void completeNow() {
    _stateController.add(TtsPlayerState.completed);
  }
}

class _ThrowingPlayer extends _RecordingAudioPlayer {
  @override
  Future<void> play() async {
    calls.add('play');
    throw StateError('play failed');
  }
}

void main() {
  group('SegmentPlayer.playSegment', () {
    test('setFilePath is called BEFORE listening to playerStateStream',
        () async {
      final player = _RecordingAudioPlayer()..autoComplete = true;
      final segmentPlayer = SegmentPlayer(
        player: player,
        bufferDrainDelay: Duration.zero,
      );

      await segmentPlayer.playSegment('/tmp/seg.wav', isLast: true);

      final setFilePathIdx =
          player.calls.indexOf('setFilePath:/tmp/seg.wav');
      final listenIdx = player.calls.indexOf('listen');
      expect(setFilePathIdx >= 0, isTrue);
      expect(listenIdx >= 0, isTrue);
      expect(setFilePathIdx, lessThan(listenIdx),
          reason: 'setFilePath must come BEFORE listen so the BehaviorSubject '
              "doesn't replay a stale 'completed' state");
    });

    test('play() is fire-and-forget; completion comes via the state stream',
        () async {
      final player = _RecordingAudioPlayer();
      final segmentPlayer = SegmentPlayer(
        player: player,
        bufferDrainDelay: Duration.zero,
      );

      final future = segmentPlayer.playSegment('/tmp/a.wav', isLast: false);
      // Without a completed event, the future should not resolve.
      var resolved = false;
      future.then((_) => resolved = true);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      expect(resolved, isFalse);
      expect(player.calls.contains('play'), isTrue);

      // Emit completed and the future should resolve.
      player.completeNow();
      await future;
      expect(resolved, isTrue);
    });

    test('intermediate segment calls pause(), never stop()', () async {
      final player = _RecordingAudioPlayer()..autoComplete = true;
      final segmentPlayer = SegmentPlayer(
        player: player,
        bufferDrainDelay: Duration.zero,
      );

      await segmentPlayer.playSegment('/tmp/a.wav', isLast: false);

      expect(player.calls.contains('pause'), isTrue,
          reason: 'intermediate segment must pause to reset playing flag');
      expect(player.calls.contains('stop'), isFalse,
          reason: 'stop() destroys the platform player and kills WASAPI buffer');
    });

    test('last segment does not call pause() (no follow-up play)', () async {
      final player = _RecordingAudioPlayer()..autoComplete = true;
      final segmentPlayer = SegmentPlayer(
        player: player,
        bufferDrainDelay: Duration.zero,
      );

      await segmentPlayer.playSegment('/tmp/a.wav', isLast: true);

      expect(player.calls.contains('pause'), isFalse,
          reason: 'last segment does not need to reset playing flag');
    });

    test('isLast: true waits for bufferDrainDelay before resolving', () async {
      final player = _RecordingAudioPlayer()..autoComplete = true;
      const delay = Duration(milliseconds: 100);
      final segmentPlayer = SegmentPlayer(
        player: player,
        bufferDrainDelay: delay,
      );

      final stopwatch = Stopwatch()..start();
      await segmentPlayer.playSegment('/tmp/last.wav', isLast: true);
      stopwatch.stop();

      expect(stopwatch.elapsed, greaterThanOrEqualTo(delay),
          reason: 'last segment should wait for the audio output device to drain');
    });

    test('Duration.zero applies to both intermediate and last segments',
        () async {
      final player = _RecordingAudioPlayer()..autoComplete = true;
      final segmentPlayer = SegmentPlayer(
        player: player,
        bufferDrainDelay: Duration.zero,
      );

      final stopwatch = Stopwatch()..start();
      await segmentPlayer.playSegment('/tmp/a.wav', isLast: false);
      await segmentPlayer.playSegment('/tmp/b.wav', isLast: true);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(50),
          reason: 'Duration.zero must short-circuit the drain in tests');
    });

    test('stop() during pending drain skips the delay', () async {
      final player = _RecordingAudioPlayer()..autoComplete = true;
      final segmentPlayer = SegmentPlayer(
        player: player,
        bufferDrainDelay: const Duration(seconds: 5),
      );

      final future = segmentPlayer.playSegment('/tmp/a.wav', isLast: true);
      // Wait long enough for play->completed->drain to start.
      await Future.delayed(const Duration(milliseconds: 50));

      final stopwatch = Stopwatch()..start();
      await segmentPlayer.stop();
      await future;
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 4)),
          reason: 'stop() should skip the pending drain delay');
    });

    test('playSegment surfaces a play() error as a Future error', () async {
      final player = _ThrowingPlayer();
      final segmentPlayer = SegmentPlayer(
        player: player,
        bufferDrainDelay: Duration.zero,
      );

      expect(
        () => segmentPlayer.playSegment('/tmp/a.wav', isLast: false),
        throwsA(isA<StateError>()),
      );
    });
  });
}
