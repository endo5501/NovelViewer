import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'text_segmenter.dart';
import 'tts_audio_repository.dart';
import 'tts_dictionary_repository.dart';
import 'tts_isolate.dart';
import 'tts_playback_controller.dart';
import 'tts_session.dart';
import 'wav_writer.dart';
import '../domain/tts_engine_config.dart';
import '../domain/tts_episode_status.dart';
import '../domain/tts_ref_wav_resolver.dart';
import '../domain/tts_segment.dart';
import '../providers/tts_playback_providers.dart';

class TtsStreamingController {
  static final _log = Logger('tts.streaming');

  TtsStreamingController({
    required this.ref,
    required TtsIsolate ttsIsolate,
    required TtsAudioPlayer audioPlayer,
    required TtsAudioRepository repository,
    required this.tempDirPath,
    Duration bufferDrainDelay = const Duration(milliseconds: 500),
    TtsDictionaryRepository? dictionaryRepository,
    TtsSession? session,
  })  : _audioPlayer = audioPlayer,
        _repository = repository,
        _bufferDrainDelay = bufferDrainDelay,
        _dictionaryRepository = dictionaryRepository,
        _session = session ?? TtsSession(isolate: ttsIsolate);

  final ProviderContainer ref;
  final TtsSession _session;
  final TtsAudioPlayer _audioPlayer;
  final TtsAudioRepository _repository;
  final TtsDictionaryRepository? _dictionaryRepository;
  final String tempDirPath;
  final Duration _bufferDrainDelay;
  final _textSegmenter = TextSegmenter();

  bool _stopped = false;
  final _writtenFiles = <String>[];
  Completer<void>? _activePlayCompleter;

  Future<void> start({
    required String text,
    required String fileName,
    required TtsEngineConfig config,
    int? startOffset,
    String Function(String fileName)? resolveRefWavPath,
  }) async {
    _stopped = false;

    final textHash = sha256.convert(utf8.encode(text)).toString();
    final segments = _textSegmenter.splitIntoSentences(text);
    if (segments.isEmpty) return;

    // Engine-config-derived values used for episode bookkeeping. The fallback
    // refWavPath only applies to Qwen3 (Piper does not do voice cloning).
    final fallbackRefWavPath = switch (config) {
      Qwen3EngineConfig(:final refWavPath) => refWavPath,
      PiperEngineConfig() => null,
    };

    // Check existing episode
    var episode = await _repository.findEpisodeByFileName(fileName);
    int? episodeId;

    if (episode != null) {
      if (episode.textHash != null && episode.textHash == textHash) {
        // Text unchanged - reuse existing data
        episodeId = episode.id;
      } else {
        // Text changed - delete and start fresh
        await _repository.deleteEpisode(episode.id);
        episode = null;
      }
    }

    episodeId ??= await _repository.createEpisode(
      fileName: fileName,
      sampleRate: config.sampleRate,
      status: TtsEpisodeStatus.generating,
      refWavPath: fallbackRefWavPath,
      textHash: textHash,
    );

    // Load existing segments into a map for quick lookup
    final dbSegments = await _repository.getSegments(episodeId);
    final dbSegmentMap = <int, TtsSegment>{
      for (final row in dbSegments) row.segmentIndex: row,
    };

    // Start playback with on-demand generation
    try {
      await _startPlayback(
        episodeId: episodeId,
        segments: segments,
        dbSegmentMap: dbSegmentMap,
        config: config,
        fallbackRefWavPath: fallbackRefWavPath,
        startOffset: startOffset,
        resolveRefWavPath: resolveRefWavPath,
      );

      // Update episode status
      if (_stopped) {
        await _repository.updateEpisodeStatus(
            episodeId, TtsEpisodeStatus.partial);
      } else {
        await _repository.updateEpisodeStatus(
            episodeId, TtsEpisodeStatus.completed);
      }
    } finally {
      // Release the session's isolate resources on natural completion.
      if (_session.modelLoaded) {
        await _session.dispose();
      }
    }
  }

  Future<void> _startPlayback({
    required int episodeId,
    required List<TextSegment> segments,
    required Map<int, TtsSegment> dbSegmentMap,
    required TtsEngineConfig config,
    required String? fallbackRefWavPath,
    int? startOffset,
    String Function(String fileName)? resolveRefWavPath,
  }) async {
    // Determine starting segment
    int startIndex = 0;
    if (startOffset != null) {
      final segment =
          await _repository.findSegmentByOffset(episodeId, startOffset);
      if (segment != null) {
        startIndex = segment.segmentIndex;
      }
    }

    // Count segments needing generation for progress tracking
    int totalToGenerate = 0;
    for (var i = startIndex; i < segments.length; i++) {
      final dbRow = dbSegmentMap[i];
      if (dbRow == null || dbRow.audioData == null) {
        totalToGenerate++;
      }
    }
    int generatedSoFar = 0;

    if (totalToGenerate > 0) {
      ref.read(ttsGenerationProgressProvider.notifier).set(
          TtsGenerationProgress(current: 0, total: totalToGenerate));
    }

    // Pre-load dictionary entries once to avoid N+1 DB queries in the segment loop.
    final dict = _dictionaryRepository;
    final dictEntries = dict != null && totalToGenerate > 0
        ? await dict.getEntriesSortedByLength()
        : null;

    for (var i = startIndex; i < segments.length; i++) {
      if (_stopped) break;

      final dbRow = dbSegmentMap[i];
      final hasAudio = dbRow != null && dbRow.audioData != null;

      Uint8List audioData;
      int textOffset;
      int textLength;

      if (hasAudio) {
        // Play existing audio
        audioData = dbRow.audioData!;
        textOffset = dbRow.textOffset;
        textLength = dbRow.textLength;
      } else {
        // Generate on-demand
        ref
            .read(ttsPlaybackStateProvider.notifier)
            .set(TtsPlaybackState.waiting);

        if (!await _session.ensureModelLoaded(config)) {
          break;
        }
        if (_stopped) break;

        // Use edited text from DB if available, otherwise apply dictionary to original
        final rawText = dbRow?.text ?? segments[i].text;
        final synthText = dbRow == null && dictEntries != null
            ? TtsDictionaryRepository.applyDictionaryWithEntries(dictEntries, rawText)
            : rawText;
        final synthRefWavPath = TtsRefWavResolver.resolve(
          storedPath: dbRow?.refWavPath,
          fallbackPath: fallbackRefWavPath,
          resolver: resolveRefWavPath,
        );

        final result = await _session.synthesize(
          text: synthText,
          refWavPath: synthRefWavPath,
        );
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
            text: synthText,
            textOffset: textOffset,
            textLength: textLength,
            audioData: wavBytes,
            sampleCount: result.audio!.length,
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

      // Wait for audio output buffer to drain after each segment, including
      // the last one. eof-reached fires when the decoder finishes, but the
      // audio device (e.g. WASAPI on Windows) may still have buffered samples
      // to play. For intermediate segments, pause() resets just_audio's
      // _playing flag so the next play() call is not a no-op. For the last
      // segment, pause() is unnecessary since no subsequent play() follows.
      // pause() is used instead of stop() because stop() destroys the
      // platform (MediaKitPlayer), which kills buffered audio.
      if (!_stopped) {
        await Future<void>.delayed(_bufferDrainDelay);
        final hasNextSegment = i < segments.length - 1;
        if (!_stopped && hasNextSegment) {
          await _audioPlayer.pause();
        }
      }

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

    // Abort any in-progress synthesis so the worker Isolate becomes responsive
    _session.abort();

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

      // Clean up isolate via the session.
      await _session.dispose();
    } catch (e, st) {
      // E.g. DB closed by concurrent finally block, or audio player failing
      // to release device resources. Recovery still proceeds via the finally
      // block below; we just want the failure observable.
      _log.warning('Error during stop() cleanup', e, st);
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
