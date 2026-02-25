import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'text_segmenter.dart';
import 'tts_audio_repository.dart';
import 'tts_generation_controller.dart';
import 'tts_isolate.dart';
import 'tts_playback_controller.dart';
import '../providers/tts_playback_providers.dart';

class TtsStreamingController {
  TtsStreamingController({
    required this.ref,
    required TtsIsolate ttsIsolate,
    required TtsAudioPlayer audioPlayer,
    required TtsAudioRepository repository,
    required this.tempDirPath,
  })  : _ttsIsolate = ttsIsolate,
        _audioPlayer = audioPlayer,
        _repository = repository;

  final ProviderContainer ref;
  final TtsIsolate _ttsIsolate;
  final TtsAudioPlayer _audioPlayer;
  final TtsAudioRepository _repository;
  final String tempDirPath;
  final _textSegmenter = TextSegmenter();

  bool _stopped = false;
  bool _generationFailed = false;
  TtsGenerationController? _generationController;
  final _writtenFiles = <String>[];
  final _segmentReadyCompleters = <int, Completer<void>>{};
  Completer<void>? _activePlayCompleter;
  int _generatedUpTo = -1;

  Future<void> start({
    required String text,
    required String fileName,
    required String modelDir,
    required int sampleRate,
    String? refWavPath,
    int? startOffset,
  }) async {
    _stopped = false;
    _generationFailed = false;

    final textHash = sha256.convert(utf8.encode(text)).toString();
    final segments = _textSegmenter.splitIntoSentences(text);
    if (segments.isEmpty) return;

    // Check existing episode
    var episode = await _repository.findEpisodeByFileName(fileName);
    int? episodeId;
    int storedSegmentCount = 0;
    bool needsGeneration = true;

    if (episode != null) {
      final storedHash = episode['text_hash'] as String?;
      if (storedHash != null && storedHash == textHash) {
        // Text unchanged - reuse existing data
        episodeId = episode['id'] as int;
        storedSegmentCount = await _repository.getSegmentCount(episodeId);
        if (episode['status'] == 'completed') {
          needsGeneration = false;
        }
      } else {
        // Text changed - delete and start fresh
        await _repository.deleteEpisode(episode['id'] as int);
        episode = null;
      }
    }

    if (episodeId == null) {
      // Create new episode
      episodeId = await _repository.createEpisode(
        fileName: fileName,
        sampleRate: sampleRate,
        status: 'generating',
        refWavPath: refWavPath,
        textHash: textHash,
      );
      storedSegmentCount = 0;
    }

    // Mark stored segments as ready
    _generatedUpTo = storedSegmentCount - 1;

    if (needsGeneration && storedSegmentCount < segments.length) {
      // Start generation in background
      _startGeneration(
        text: text,
        fileName: fileName,
        modelDir: modelDir,
        sampleRate: sampleRate,
        refWavPath: refWavPath,
        episodeId: episodeId,
        startSegmentIndex: storedSegmentCount,
      );
    }

    // Start playback
    await _startPlayback(
      episodeId: episodeId,
      segments: segments,
      storedSegmentCount: storedSegmentCount,
      totalSegments: segments.length,
      needsGeneration: needsGeneration && storedSegmentCount < segments.length,
      startOffset: startOffset,
    );

    // If all done and not stopped/failed, mark completed
    if (!_stopped && !_generationFailed && needsGeneration) {
      await _repository.updateEpisodeStatus(episodeId, 'completed');
    }
  }

  void _startGeneration({
    required String text,
    required String fileName,
    required String modelDir,
    required int sampleRate,
    required int episodeId,
    required int startSegmentIndex,
    String? refWavPath,
  }) {
    final genController = TtsGenerationController(
      ttsIsolate: _ttsIsolate,
      repository: _repository,
    );
    _generationController = genController;

    genController.onSegmentStored = (segmentIndex) {
      _generatedUpTo = segmentIndex;
      final completer = _segmentReadyCompleters.remove(segmentIndex);
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    };

    genController.onProgress = (current, total) {
      ref.read(ttsGenerationProgressProvider.notifier)
          .set(TtsGenerationProgress(current: current, total: total));
    };

    genController.onError = (_) {
      _generationFailed = true;
      _releaseAllWaiters();
    };

    // Fire and forget - runs in parallel with playback
    genController.start(
      text: text,
      fileName: fileName,
      modelDir: modelDir,
      sampleRate: sampleRate,
      refWavPath: refWavPath,
      startSegmentIndex: startSegmentIndex,
      existingEpisodeId: episodeId,
    ).whenComplete(() {
      _generationController = null;
    });
  }

  Future<void> _startPlayback({
    required int episodeId,
    required List<TextSegment> segments,
    required int storedSegmentCount,
    required int totalSegments,
    required bool needsGeneration,
    int? startOffset,
  }) async {
    // Determine starting segment
    int startIndex = 0;
    if (startOffset != null) {
      final segment =
          await _repository.findSegmentByOffset(episodeId, startOffset);
      if (segment != null) {
        startIndex = segment['segment_index'] as int;
      }
    }

    for (var i = startIndex; i < totalSegments; i++) {
      if (_stopped) break;

      // Wait for segment to be available
      if (i > _generatedUpTo) {
        if (_generationFailed) break;

        ref.read(ttsPlaybackStateProvider.notifier).set(
            TtsPlaybackState.waiting);

        final completer = Completer<void>();
        _segmentReadyCompleters[i] = completer;
        await completer.future;

        if (_stopped || _generationFailed) break;
      }

      // Load individual segment from DB
      final segmentData = await _repository.getSegmentByIndex(episodeId, i);

      // Write to temp file
      final filePath = '$tempDirPath/tts_streaming_$i.wav';
      final file = File(filePath);
      await file.writeAsBytes(segmentData['audio_data'] as List<int>);
      _writtenFiles.add(filePath);

      if (_stopped) break;

      // Update highlight
      final textOffset = segmentData['text_offset'] as int;
      final textLength = segmentData['text_length'] as int;
      ref.read(ttsHighlightRangeProvider.notifier).set(
        TextRange(start: textOffset, end: textOffset + textLength),
      );

      // Play segment
      // IMPORTANT: setFilePath must come BEFORE subscribing to playerStateStream.
      // just_audio's playerStateStream is a BehaviorSubject that replays the
      // latest value. After a segment completes, the replayed state is
      // 'completed', which would immediately trigger the completer and skip
      // the segment. setFilePath resets processingState to 'ready'.
      ref.read(ttsPlaybackStateProvider.notifier).set(
          TtsPlaybackState.playing);
      await _audioPlayer.setFilePath(filePath);

      final playCompleter = Completer<void>();
      _activePlayCompleter = playCompleter;
      late StreamSubscription<TtsPlayerState> playSub;
      playSub = _audioPlayer.playerStateStream.listen((state) {
        if (state == TtsPlayerState.completed && !playCompleter.isCompleted) {
          playCompleter.complete();
        }
      });

      unawaited(_audioPlayer.play().catchError((e, st) {
        if (!playCompleter.isCompleted) playCompleter.completeError(e, st);
      }));

      await playCompleter.future;
      _activePlayCompleter = null;
      await playSub.cancel();

      if (_stopped) break;
    }

    if (!_stopped) {
      // All segments played - clean up
      ref.read(ttsPlaybackStateProvider.notifier).set(
          TtsPlaybackState.stopped);
      ref.read(ttsHighlightRangeProvider.notifier).set(null);
      await _audioPlayer.dispose();
      await _cleanupFiles();
    }
  }

  void _releaseAllWaiters() {
    for (final completer in _segmentReadyCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _segmentReadyCompleters.clear();
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

    // Cancel any waiting completers
    _releaseAllWaiters();

    // Cancel active play completion wait
    final playCompleter = _activePlayCompleter;
    if (playCompleter != null && !playCompleter.isCompleted) {
      playCompleter.complete();
    }
    _activePlayCompleter = null;

    // Stop generation
    await _generationController?.cancel();
    _generationController = null;

    // Stop playback
    await _audioPlayer.stop();
    await _audioPlayer.dispose();

    ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.stopped);
    ref.read(ttsHighlightRangeProvider.notifier).set(null);
    ref.read(ttsGenerationProgressProvider.notifier)
        .set(TtsGenerationProgress.zero);

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
