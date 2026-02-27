import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'text_segmenter.dart';
import 'tts_audio_repository.dart';
import 'tts_isolate.dart';
import 'tts_playback_controller.dart';
import 'wav_writer.dart';
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
  bool _modelLoaded = false;
  final _writtenFiles = <String>[];
  Completer<void>? _activePlayCompleter;
  StreamSubscription<TtsIsolateResponse>? _subscription;

  Future<void> start({
    required String text,
    required String fileName,
    required String modelDir,
    required int sampleRate,
    String? refWavPath,
    int? startOffset,
  }) async {
    _stopped = false;
    _modelLoaded = false;

    final textHash = sha256.convert(utf8.encode(text)).toString();
    final segments = _textSegmenter.splitIntoSentences(text);
    if (segments.isEmpty) return;

    // Check existing episode
    var episode = await _repository.findEpisodeByFileName(fileName);
    int? episodeId;

    if (episode != null) {
      final storedHash = episode['text_hash'] as String?;
      if (storedHash != null && storedHash == textHash) {
        // Text unchanged - reuse existing data
        episodeId = episode['id'] as int;
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
    }

    // Load existing segments into a map for quick lookup
    final dbSegments = await _repository.getSegments(episodeId);
    final dbSegmentMap = <int, Map<String, Object?>>{};
    for (final row in dbSegments) {
      dbSegmentMap[row['segment_index'] as int] = row;
    }

    // Start playback with on-demand generation
    await _startPlayback(
      episodeId: episodeId,
      segments: segments,
      dbSegmentMap: dbSegmentMap,
      modelDir: modelDir,
      sampleRate: sampleRate,
      refWavPath: refWavPath,
      startOffset: startOffset,
    );

    // Update episode status
    if (_stopped) {
      await _repository.updateEpisodeStatus(episodeId, 'partial');
    } else {
      await _repository.updateEpisodeStatus(episodeId, 'completed');
    }
  }

  Future<bool> _ensureModelLoaded(String modelDir) async {
    if (_modelLoaded) return true;

    await _ttsIsolate.spawn();

    final completer = Completer<bool>();
    _subscription = _ttsIsolate.responses.listen((response) {
      if (response is ModelLoadedResponse && !completer.isCompleted) {
        completer.complete(response.success);
      }
    });

    _ttsIsolate.loadModel(modelDir);
    _modelLoaded = await completer.future;
    return _modelLoaded;
  }

  Future<SynthesisResultResponse?> _synthesize(
      String text, String? refWavPath) async {
    final completer = Completer<SynthesisResultResponse>();

    late StreamSubscription<TtsIsolateResponse> sub;
    sub = _ttsIsolate.responses.listen((response) {
      if (response is SynthesisResultResponse && !completer.isCompleted) {
        completer.complete(response);
      }
    });

    _ttsIsolate.synthesize(text, refWavPath: refWavPath);

    try {
      final result = await completer.future;
      if (result.error != null || result.audio == null) {
        return null;
      }
      return result;
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _startPlayback({
    required int episodeId,
    required List<TextSegment> segments,
    required Map<int, Map<String, Object?>> dbSegmentMap,
    required String modelDir,
    required int sampleRate,
    required String? refWavPath,
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

    // Count segments needing generation for progress tracking
    int totalToGenerate = 0;
    for (var i = startIndex; i < segments.length; i++) {
      final dbRow = dbSegmentMap[i];
      if (dbRow == null || dbRow['audio_data'] == null) {
        totalToGenerate++;
      }
    }
    int generatedSoFar = 0;

    if (totalToGenerate > 0) {
      ref.read(ttsGenerationProgressProvider.notifier).set(
          TtsGenerationProgress(current: 0, total: totalToGenerate));
    }

    for (var i = startIndex; i < segments.length; i++) {
      if (_stopped) break;

      final dbRow = dbSegmentMap[i];
      final hasAudio = dbRow != null && dbRow['audio_data'] != null;

      Uint8List audioData;
      int textOffset;
      int textLength;

      if (hasAudio) {
        // Play existing audio
        audioData = Uint8List.fromList(dbRow!['audio_data'] as List<int>);
        textOffset = dbRow['text_offset'] as int;
        textLength = dbRow['text_length'] as int;
      } else {
        // Generate on-demand
        ref
            .read(ttsPlaybackStateProvider.notifier)
            .set(TtsPlaybackState.waiting);

        if (!await _ensureModelLoaded(modelDir)) break;
        if (_stopped) break;

        // Use edited text from DB if available, otherwise original
        final synthText =
            dbRow?['text'] as String? ?? segments[i].text;
        final synthRefWavPath =
            dbRow?['ref_wav_path'] as String? ?? refWavPath;

        final result = await _synthesize(synthText, synthRefWavPath);
        if (result == null || _stopped) break;

        final wavBytes = WavWriter.toBytes(
          audio: result.audio!,
          sampleRate: result.sampleRate,
        );

        textOffset = segments[i].offset;
        textLength = segments[i].length;

        // Store in DB
        if (dbRow != null) {
          await _repository.updateSegmentAudio(
              episodeId, i, wavBytes, result.audio!.length);
        } else {
          await _repository.insertSegment(
            episodeId: episodeId,
            segmentIndex: i,
            text: segments[i].text,
            textOffset: textOffset,
            textLength: textLength,
            audioData: wavBytes,
            sampleCount: result.audio!.length,
            refWavPath: refWavPath,
          );
        }

        audioData = wavBytes;
        generatedSoFar++;
        ref.read(ttsGenerationProgressProvider.notifier).set(
            TtsGenerationProgress(
                current: generatedSoFar, total: totalToGenerate));
      }

      // Write to temp file
      final filePath = '$tempDirPath/tts_streaming_$i.wav';
      final file = File(filePath);
      await file.writeAsBytes(audioData);
      _writtenFiles.add(filePath);

      if (_stopped) break;

      // Update highlight
      ref.read(ttsHighlightRangeProvider.notifier).set(
            TextRange(start: textOffset, end: textOffset + textLength),
          );

      // Play segment
      // IMPORTANT: setFilePath must come BEFORE subscribing to playerStateStream.
      // just_audio's playerStateStream is a BehaviorSubject that replays the
      // latest value. After a segment completes, the replayed state is
      // 'completed', which would immediately trigger the completer and skip
      // the segment. setFilePath resets processingState to 'ready'.
      ref
          .read(ttsPlaybackStateProvider.notifier)
          .set(TtsPlaybackState.playing);
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
      ref
          .read(ttsPlaybackStateProvider.notifier)
          .set(TtsPlaybackState.stopped);
      ref.read(ttsHighlightRangeProvider.notifier).set(null);
      await _audioPlayer.dispose();
      await _cleanupFiles();
    }
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

    // Cancel active play completion wait
    final playCompleter = _activePlayCompleter;
    if (playCompleter != null && !playCompleter.isCompleted) {
      playCompleter.complete();
    }
    _activePlayCompleter = null;

    try {
      // Stop playback
      await _audioPlayer.stop();
      await _audioPlayer.dispose();

      // Clean up isolate if loaded
      if (_modelLoaded) {
        await _ttsIsolate.dispose();
        _modelLoaded = false;
      }
      await _subscription?.cancel();
      _subscription = null;
    } catch (_) {
      // Ignore cleanup errors (e.g. DB closed by concurrent finally block)
    } finally {
      // Always clear state even if cleanup throws
      ref
          .read(ttsPlaybackStateProvider.notifier)
          .set(TtsPlaybackState.stopped);
      ref.read(ttsHighlightRangeProvider.notifier).set(null);
      ref
          .read(ttsGenerationProgressProvider.notifier)
          .set(TtsGenerationProgress.zero);
    }

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
