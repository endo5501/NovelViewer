import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'text_segmenter.dart';
import 'tts_isolate.dart';
import '../providers/tts_playback_providers.dart';

/// Abstraction for audio player to enable testing.
abstract class TtsAudioPlayer {
  Stream<TtsPlayerState> get playerStateStream;
  Future<void> setFilePath(String path);
  Future<void> play();
  Future<void> stop();
  Future<void> dispose();
}

/// Simple player state for TTS playback.
enum TtsPlayerState { playing, paused, completed, stopped }

/// Abstraction for WAV file writing to enable testing.
abstract class TtsWavWriter {
  Future<void> write({
    required String path,
    required Float32List audio,
    required int sampleRate,
  });
}

/// Abstraction for file cleanup to enable testing.
abstract class TtsFileCleaner {
  Future<void> deleteFile(String path);
}

/// Determines the starting character offset for TTS playback.
///
/// If [selectedText] is non-null, non-empty, and found in [text],
/// returns the offset of its first occurrence.
/// Otherwise, returns [viewStartCharOffset] (defaults to 0).
int determineStartOffset({
  required String text,
  String? selectedText,
  int viewStartCharOffset = 0,
}) {
  if (selectedText != null && selectedText.isNotEmpty) {
    final index = text.indexOf(selectedText);
    if (index >= 0) return index;
  }
  return viewStartCharOffset;
}

/// Orchestrates the TTS playback pipeline:
/// text segmentation → TTS synthesis → WAV writing → audio playback → highlight update.
class TtsPlaybackController {
  TtsPlaybackController({
    required this.ref,
    required TtsIsolate ttsIsolate,
    required TtsAudioPlayer audioPlayer,
    required TtsWavWriter wavWriter,
    required TtsFileCleaner fileCleaner,
    required this.tempDirPath,
  })  : _ttsIsolate = ttsIsolate,
        _audioPlayer = audioPlayer,
        _wavWriter = wavWriter,
        _fileCleaner = fileCleaner;

  final ProviderContainer ref;
  final TtsIsolate _ttsIsolate;
  final TtsAudioPlayer _audioPlayer;
  final TtsWavWriter _wavWriter;
  final TtsFileCleaner _fileCleaner;
  final String tempDirPath;

  final _textSegmenter = TextSegmenter();
  List<TextSegment> _segments = [];
  int _currentSegmentIndex = 0;
  final _writtenFiles = <String>[];
  StreamSubscription<TtsIsolateResponse>? _isolateSubscription;
  StreamSubscription<TtsPlayerState>? _playerSubscription;
  bool _stopped = false;

  // Prefetch state
  Float32List? _prefetchedAudio;
  int _prefetchedSampleRate = 0;
  bool _isPrefetching = false;

  /// Start TTS playback.
  ///
  /// [text] - The full text to read.
  /// [modelDir] - Path to the TTS model directory.
  /// [startOffset] - Character offset to begin reading from (default: 0).
  /// [refWavPath] - Optional reference WAV for voice cloning.
  Future<void> start({
    required String text,
    required String modelDir,
    int startOffset = 0,
    String? refWavPath,
  }) async {
    _stopped = false;
    _prefetchedAudio = null;
    _isPrefetching = false;

    // Set loading state
    ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.loading);

    // Split text into segments
    _segments = _textSegmenter.splitIntoSentences(text);
    if (_segments.isEmpty) {
      ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.stopped);
      return;
    }

    // Find starting segment based on offset
    final idx = _segments.indexWhere(
      (s) => s.offset + s.length > startOffset,
    );
    _currentSegmentIndex = idx >= 0 ? idx : _segments.length - 1;

    // Spawn isolate and load model
    await _ttsIsolate.spawn();

    // Listen for isolate responses
    final modelCompleter = Completer<bool>();
    _isolateSubscription = _ttsIsolate.responses.listen((response) {
      if (_stopped) return;

      if (response is ModelLoadedResponse) {
        if (!modelCompleter.isCompleted) {
          modelCompleter.complete(response.success);
          if (!response.success) {
            _handleError('Model load failed: ${response.error}');
          }
        }
      } else if (response is SynthesisResultResponse) {
        _handleSynthesisResult(response, refWavPath);
      }
    });

    _ttsIsolate.loadModel(modelDir);

    // Wait for model to load
    final success = await modelCompleter.future;
    if (!success || _stopped) return;

    // Listen for audio player state changes
    _playerSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state == TtsPlayerState.completed && !_stopped) {
        _onPlaybackCompleted(refWavPath);
      }
    });

    // Start synthesizing the first segment
    _synthesizeCurrentSegment(refWavPath);
  }

  void _synthesizeCurrentSegment(String? refWavPath) {
    if (_currentSegmentIndex >= _segments.length || _stopped) return;

    final segment = _segments[_currentSegmentIndex];
    _ttsIsolate.synthesize(segment.text, refWavPath: refWavPath);
  }

  void _handleSynthesisResult(
      SynthesisResultResponse response, String? refWavPath) {
    if (_stopped) return;

    if (response.error != null || response.audio == null) {
      _handleError('Synthesis failed: ${response.error}');
      return;
    }

    if (_isPrefetching) {
      // Store prefetched audio for next segment
      _prefetchedAudio = response.audio;
      _prefetchedSampleRate = response.sampleRate;
      _isPrefetching = false;
      return;
    }

    // Write WAV and play
    _writeAndPlay(response.audio!, response.sampleRate, refWavPath);
  }

  Future<void> _writeAndPlay(
      Float32List audio, int sampleRate, String? refWavPath) async {
    if (_stopped) return;

    final filePath =
        '$tempDirPath/tts_segment_$_currentSegmentIndex.wav';
    await _wavWriter.write(
      path: filePath,
      audio: audio,
      sampleRate: sampleRate,
    );
    _writtenFiles.add(filePath);

    if (_stopped) return;

    // Update highlight
    final segment = _segments[_currentSegmentIndex];
    ref.read(ttsHighlightRangeProvider.notifier).set(
      TextRange(start: segment.offset, end: segment.offset + segment.length),
    );

    // Set state to playing
    ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.playing);

    // Play the audio
    await _audioPlayer.setFilePath(filePath);
    await _audioPlayer.play();

    // Start prefetching next segment
    _startPrefetch(refWavPath);
  }

  void _startPrefetch(String? refWavPath) {
    final nextIndex = _currentSegmentIndex + 1;
    if (nextIndex >= _segments.length || _stopped) return;

    _isPrefetching = true;
    _ttsIsolate.synthesize(_segments[nextIndex].text, refWavPath: refWavPath);
  }

  void _onPlaybackCompleted(String? refWavPath) {
    _currentSegmentIndex++;

    if (_currentSegmentIndex >= _segments.length) {
      // All segments done
      stop();
      return;
    }

    if (_prefetchedAudio != null) {
      // Use prefetched audio
      final audio = _prefetchedAudio!;
      final sampleRate = _prefetchedSampleRate;
      _prefetchedAudio = null;
      _writeAndPlay(audio, sampleRate, refWavPath);
    } else {
      // Synthesize next segment (no prefetch available)
      _synthesizeCurrentSegment(refWavPath);
    }
  }

  void _handleError(String message) => stop();

  /// Stop TTS playback and clean up resources.
  ///
  /// Safe to call multiple times (idempotent).
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _prefetchedAudio = null;
    _isPrefetching = false;

    await _isolateSubscription?.cancel();
    _isolateSubscription = null;
    await _playerSubscription?.cancel();
    _playerSubscription = null;

    _ttsIsolate.dispose();
    await _audioPlayer.stop();

    // Reset state
    ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.stopped);
    ref.read(ttsHighlightRangeProvider.notifier).set(null);

    // Clean up temp files
    await _cleanupFiles();
  }

  Future<void> _cleanupFiles() async {
    for (final file in _writtenFiles) {
      await _fileCleaner.deleteFile(file);
    }
    _writtenFiles.clear();
  }
}
