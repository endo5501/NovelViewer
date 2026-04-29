import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'segment_player.dart';
import 'tts_audio_repository.dart';
import 'tts_playback_controller.dart';
import '../domain/tts_segment.dart';
import '../providers/tts_playback_providers.dart';

class TtsStoredPlayerController {
  TtsStoredPlayerController({
    required this.ref,
    required TtsAudioPlayer audioPlayer,
    required TtsAudioRepository repository,
    required this.tempDirPath,
    Duration bufferDrainDelay = const Duration(milliseconds: 500),
    SegmentPlayer? segmentPlayer,
  })  : _repository = repository,
        _segmentPlayer = segmentPlayer ??
            SegmentPlayer(
              player: audioPlayer,
              bufferDrainDelay: bufferDrainDelay,
            );

  final ProviderContainer ref;
  final SegmentPlayer _segmentPlayer;
  final TtsAudioRepository _repository;
  final String tempDirPath;

  List<TtsSegment> _segments = [];
  final _writtenFiles = <String>[];
  bool _stopped = false;

  Future<void> start({
    required int episodeId,
    int? startOffset,
  }) async {
    _stopped = false;

    _segments = await _repository.getSegments(episodeId);
    if (_segments.isEmpty) return;

    int currentSegmentIndex = 0;
    if (startOffset != null) {
      final segment =
          await _repository.findSegmentByOffset(episodeId, startOffset);
      if (segment != null) {
        final found = _segments.indexWhere(
            (s) => s.segmentIndex == segment.segmentIndex);
        if (found >= 0) currentSegmentIndex = found;
      }
    }

    for (var i = currentSegmentIndex; i < _segments.length; i++) {
      if (_stopped) break;

      final segment = _segments[i];
      final audioData = segment.audioData;
      if (audioData == null) continue;

      final filePath = '$tempDirPath/tts_playback_$i.wav';
      final file = File(filePath);
      await file.writeAsBytes(audioData);
      _writtenFiles.add(filePath);

      if (_stopped) break;

      ref.read(ttsHighlightRangeProvider.notifier).set(
            TextRange(
              start: segment.textOffset,
              end: segment.textOffset + segment.textLength,
            ),
          );
      ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.playing);

      final isLast = i == _segments.length - 1;
      await _segmentPlayer.playSegment(filePath, isLast: isLast);
    }

    if (!_stopped) {
      await stop();
    }
  }

  Future<void> pause() async {
    // SegmentPlayer doesn't expose pause directly — but pausing the underlying
    // player is what TtsAudioPlayer.pause() does. We rely on the controller
    // exposing that knob to the UI; for now, route through stop() which is
    // user-initiated.
    ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.paused);
  }

  Future<void> resume() async {
    ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.playing);
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;

    await _segmentPlayer.stop();
    await _segmentPlayer.dispose();

    try {
      await _cleanupFiles();
    } finally {
      ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.stopped);
      ref.read(ttsHighlightRangeProvider.notifier).set(null);
    }
  }

  Future<void> _cleanupFiles() async {
    for (final path in _writtenFiles) {
      try {
        await File(path).delete();
      } on PathNotFoundException {
        // File or parent directory already deleted
      }
    }
    _writtenFiles.clear();
  }
}
