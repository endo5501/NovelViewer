import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tts_audio_repository.dart';
import 'tts_playback_controller.dart';
import '../providers/tts_playback_providers.dart';

class TtsStoredPlayerController {
  TtsStoredPlayerController({
    required this.ref,
    required TtsAudioPlayer audioPlayer,
    required TtsAudioRepository repository,
    required this.tempDirPath,
  })  : _audioPlayer = audioPlayer,
        _repository = repository;

  final ProviderContainer ref;
  final TtsAudioPlayer _audioPlayer;
  final TtsAudioRepository _repository;
  final String tempDirPath;

  List<Map<String, Object?>> _segments = [];
  int _currentSegmentIndex = 0;
  final _writtenFiles = <String>[];
  StreamSubscription<TtsPlayerState>? _playerSubscription;
  bool _stopped = false;

  Future<void> start({
    required int episodeId,
    int? startOffset,
  }) async {
    _stopped = false;

    // Load all segments
    _segments = await _repository.getSegments(episodeId);
    if (_segments.isEmpty) return;

    // Determine starting segment
    _currentSegmentIndex = 0;
    if (startOffset != null) {
      final segment =
          await _repository.findSegmentByOffset(episodeId, startOffset);
      if (segment != null) {
        final found = _segments.indexWhere(
            (s) => s['segment_index'] == segment['segment_index']);
        if (found >= 0) _currentSegmentIndex = found;
      }
    }

    // Listen for playback completion
    _playerSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state == TtsPlayerState.completed && !_stopped) {
        _onSegmentCompleted();
      }
    });

    // Start playing the first segment
    await _playCurrentSegment();
  }

  Future<void> _playCurrentSegment() async {
    if (_currentSegmentIndex >= _segments.length || _stopped) return;

    final segment = _segments[_currentSegmentIndex];
    final audioData = segment['audio_data'] as Uint8List;

    // Write BLOB to temp file
    final filePath =
        '$tempDirPath/tts_playback_$_currentSegmentIndex.wav';
    final file = File(filePath);
    await file.writeAsBytes(audioData);
    _writtenFiles.add(filePath);

    if (_stopped) return;

    // Update highlight
    final textOffset = segment['text_offset'] as int;
    final textLength = segment['text_length'] as int;
    ref.read(ttsHighlightRangeProvider.notifier).set(
      TextRange(start: textOffset, end: textOffset + textLength),
    );

    // Set state to playing
    ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.playing);

    // Play
    await _audioPlayer.setFilePath(filePath);
    await _audioPlayer.play();
  }

  void _onSegmentCompleted() {
    _currentSegmentIndex++;

    if (_currentSegmentIndex >= _segments.length) {
      stop();
      return;
    }

    _playCurrentSegment();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.paused);
  }

  Future<void> resume() async {
    await _audioPlayer.play();
    ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.playing);
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;

    await _playerSubscription?.cancel();
    _playerSubscription = null;

    await _audioPlayer.stop();
    await _audioPlayer.dispose();

    ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.stopped);
    ref.read(ttsHighlightRangeProvider.notifier).set(null);

    await _cleanupFiles();
  }

  Future<void> _cleanupFiles() async {
    for (final path in _writtenFiles) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _writtenFiles.clear();
  }
}
