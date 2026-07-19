import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:logging/logging.dart';

import '../../../shared/utils/content_hash.dart';
import 'segment_player.dart';
import 'text_segmenter.dart';
import 'tts_audio_repository.dart';
import '../providers/text_segmenter_provider.dart';
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

/// Reads a Riverpod provider value. Compatible with both
/// `WidgetRef.read` and `ProviderContainer.read`, which lets call sites pass
/// `ref.read` from a `ConsumerStatefulWidget` without leaking a
/// `ProviderContainer` reference into the controller (F046).
typedef Reader = T Function<T>(ProviderListenable<T> provider);

/// Result of a streaming `start()` run, letting callers distinguish a normal
/// completion, a user stop, and a genuine engine failure (F101). A `failed`
/// outcome is what the UI uses to surface an error to the user; it covers both
/// a zero-audio failure and a mid-stream failure that kept some audio.
enum TtsStartOutcome { completed, stopped, failed }

class TtsStreamingController {
  static final _log = Logger('tts.streaming');

  TtsStreamingController({
    required Reader read,
    required TtsIsolate ttsIsolate,
    required TtsAudioPlayer audioPlayer,
    required TtsAudioRepository repository,
    required this.tempDirPath,
    Duration bufferDrainDelay = const Duration(milliseconds: 500),
    TtsDictionaryRepository? dictionaryRepository,
    TtsSession? session,
    SegmentPlayer? segmentPlayer,
  })  : _read = read,
        _repository = repository,
        _dictionaryRepository = dictionaryRepository,
        _session = session ?? TtsSession(isolate: ttsIsolate),
        _segmentPlayer = segmentPlayer ??
            SegmentPlayer(
              player: audioPlayer,
              bufferDrainDelay: bufferDrainDelay,
            );

  final Reader _read;
  final TtsSession _session;
  final SegmentPlayer _segmentPlayer;
  final TtsAudioRepository _repository;
  final TtsDictionaryRepository? _dictionaryRepository;
  final String tempDirPath;
  late final TextSegmenter _textSegmenter = _read(textSegmenterProvider);

  bool _stopped = false;
  final _writtenFiles = <String>[];

  Future<TtsStartOutcome> start({
    required String text,
    required String fileName,
    required TtsEngineConfig config,
    int? startOffset,
    String Function(String fileName)? resolveRefWavPath,
  }) async {
    _stopped = false;

    final textHash = computeContentHash(text);
    final segments = _textSegmenter.splitIntoSentences(text);
    if (segments.isEmpty) return TtsStartOutcome.completed;

    // Engine-config-derived values used for episode bookkeeping. The fallback
    // refWavPath only applies to Qwen3 (Piper does not do voice cloning).
    final fallbackRefWavPath = switch (config) {
      Qwen3EngineConfig(:final refWavPath) => refWavPath,
      PiperEngineConfig() => null,
      // Placeholder: Irodori's refWavPath fallback wiring into the
      // streaming pipeline lands in task 5.x.
      IrodoriEngineConfig() => null,
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

    // Start playback with on-demand generation.
    //
    // Note: failure detection here assumes `ensureModelLoaded`/`synthesize`
    // actually return. If the worker isolate dies and the completer never
    // resolves, this loop hangs and the status is never updated. That hang
    // (missing timeout / isolate liveness monitoring) is tracked separately as
    // F144 and is out of scope for this change.
    try {
      final failed = await _startPlayback(
        episodeId: episodeId,
        segments: segments,
        dbSegmentMap: dbSegmentMap,
        config: config,
        fallbackRefWavPath: fallbackRefWavPath,
        startOffset: startOffset,
        resolveRefWavPath: resolveRefWavPath,
      );

      // Resolve the terminal status. A user stop and an engine failure both
      // exit the loop early, but only a failure (F101) is surfaced as an
      // error: a stop keeps `partial`, while a failure with no usable audio
      // deletes the episode so the file reverts to `none` instead of showing
      // a phantom "ready" episode.
      if (_stopped) {
        await _repository.updateEpisodeStatus(
            episodeId, TtsEpisodeStatus.partial);
        return TtsStartOutcome.stopped;
      }
      if (failed) {
        // Use a COUNT query rather than loading every segment's WAV blob just
        // to test for presence of audio on this (failure) path.
        final hasAudio =
            await _repository.getGeneratedSegmentCount(episodeId) > 0;
        if (hasAudio) {
          await _repository.updateEpisodeStatus(
              episodeId, TtsEpisodeStatus.partial);
        } else {
          await _repository.deleteEpisode(episodeId);
        }
        return TtsStartOutcome.failed;
      }
      await _repository.updateEpisodeStatus(
          episodeId, TtsEpisodeStatus.completed);
      return TtsStartOutcome.completed;
    } finally {
      // Always release isolate + segment-player resources and clear temp
      // files, even on early exit (model-load failure, exception).
      await _session.dispose();
      if (!_stopped) {
        await _segmentPlayer.dispose();
        await _cleanupFiles();
      }
    }
  }

  /// Runs the generation/playback loop. Returns `true` if the loop exited
  /// because of a genuine engine failure (model-load or synthesis), as opposed
  /// to a user stop (`_stopped`) or a normal completion.
  Future<bool> _startPlayback({
    required int episodeId,
    required List<TextSegment> segments,
    required Map<int, TtsSegment> dbSegmentMap,
    required TtsEngineConfig config,
    required String? fallbackRefWavPath,
    int? startOffset,
    String Function(String fileName)? resolveRefWavPath,
  }) async {
    var failed = false;

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
      _read(ttsGenerationProgressProvider.notifier).set(
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
        _read(ttsPlaybackStateProvider.notifier)
            .set(TtsPlaybackState.waiting);

        if (!await _session.ensureModelLoaded(config)) {
          // `ensureModelLoaded` returns false on a real failure or because an
          // abort (from stop()) completed it. Since stop() sets `_stopped`
          // before calling abort(), a false return while `_stopped` is false
          // is always a genuine model-load failure.
          if (!_stopped) failed = true;
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
        // A null result is either a real synthesis failure or an abort. As
        // with model load, an abort implies `_stopped` is already true, so a
        // null while `_stopped` is false is a genuine synthesis failure.
        if (result == null) {
          if (!_stopped) failed = true;
          break;
        }
        if (_stopped) break;

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
        _read(ttsGenerationProgressProvider.notifier).set(
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
      _read(ttsHighlightRangeProvider.notifier).set(
            TextRange(start: textOffset, end: textOffset + textLength),
          );

      _read(ttsPlaybackStateProvider.notifier)
          .set(TtsPlaybackState.playing);

      final isLast = i == segments.length - 1;
      await _segmentPlayer.playSegment(filePath, isLast: isLast);

      if (_stopped) break;
    }

    if (!_stopped) {
      // All segments played — clear UI state. The segment player and temp
      // files are disposed by `start()`'s outer finally so this branch and
      // the exception path stay symmetric.
      _read(ttsPlaybackStateProvider.notifier)
          .set(TtsPlaybackState.stopped);
      _read(ttsHighlightRangeProvider.notifier).set(null);
    }

    return failed;
  }

  Future<void> pause() async {
    await _segmentPlayer.pause();
    _read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.paused);
  }

  Future<void> resume() async {
    await _segmentPlayer.resume();
    _read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.playing);
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;

    // Abort any in-progress synthesis so the worker Isolate becomes responsive
    _session.abort();

    try {
      // Stop playback (skips any pending buffer-drain delay).
      await _segmentPlayer.stop();
      await _segmentPlayer.dispose();

      // Clean up isolate via the session.
      await _session.dispose();
    } catch (e, st) {
      // E.g. DB closed by concurrent finally block, or audio player failing
      // to release device resources. Recovery still proceeds via the finally
      // block below; we just want the failure observable.
      _log.warning('Error during stop() cleanup', e, st);
    } finally {
      // Always clear state even if cleanup throws
      _read(ttsPlaybackStateProvider.notifier)
          .set(TtsPlaybackState.stopped);
      _read(ttsHighlightRangeProvider.notifier).set(null);
      _read(ttsGenerationProgressProvider.notifier)
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
