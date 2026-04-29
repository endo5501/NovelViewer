import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'segment_player.dart';
import 'text_segmenter.dart';
import 'tts_audio_repository.dart';
import 'tts_dictionary_repository.dart';
import 'tts_edit_segment.dart';
import 'tts_isolate.dart';
import 'tts_playback_controller.dart';
import 'tts_session.dart';
import 'wav_writer.dart';
import '../domain/tts_engine_config.dart';
import '../domain/tts_episode_status.dart';
import '../domain/tts_ref_wav_resolver.dart';
import '../domain/tts_segment.dart';

class TtsEditController {
  TtsEditController({
    required TtsIsolate ttsIsolate,
    required TtsAudioPlayer audioPlayer,
    required TtsAudioRepository repository,
    required this.tempDirPath,
    TtsIsolate Function()? ttsIsolateFactory,
    TtsDictionaryRepository? dictionaryRepository,
    TtsSession? session,
    SegmentPlayer? segmentPlayer,
    TextSegmenter? textSegmenter,
  })  : _repository = repository,
        _ttsIsolateFactory = ttsIsolateFactory ?? TtsIsolate.new,
        _dictionaryRepository = dictionaryRepository,
        _session = session ?? TtsSession(isolate: ttsIsolate),
        _segmentPlayer = segmentPlayer ??
            // Edit-screen previews always treat each segment as the last one
            // (no follow-up play()), so default drain to zero — the WASAPI
            // tail concern only applies to back-to-back segment playback.
            SegmentPlayer(player: audioPlayer, bufferDrainDelay: Duration.zero),
        _textSegmenter = textSegmenter ?? const TextSegmenter();

  TtsSession _session;
  final SegmentPlayer _segmentPlayer;
  final TtsIsolate Function() _ttsIsolateFactory;
  final TtsAudioRepository _repository;
  final TtsDictionaryRepository? _dictionaryRepository;
  final String tempDirPath;
  final TextSegmenter _textSegmenter;

  List<TtsEditSegment> _segments = [];
  List<TtsEditSegment> get segments => _segments;

  bool get modelLoaded => _session.modelLoaded;

  bool _cancelled = false;
  int? _episodeId;
  String? _fileName;
  String? _textHash;
  int _sampleRate = 24000;
  final _writtenFiles = <String>[];

  void Function(int segmentIndex)? onSegmentGenerated;
  void Function(int current, int total)? onProgress;
  void Function(String error)? onError;

  Future<void> loadSegments({
    required String text,
    required String fileName,
    required int sampleRate,
  }) async {
    _sampleRate = sampleRate;
    _fileName = fileName;
    _textHash = sha256.convert(utf8.encode(text)).toString();

    final originalSegments = _textSegmenter.splitIntoSentences(text);

    final episode = await _repository.findEpisodeByFileName(fileName);
    List<TtsSegment> dbSegments = [];

    if (episode != null) {
      _episodeId = episode.id;
      dbSegments = await _repository.getSegments(_episodeId!);

      // Backfill text_hash for episodes created before this fix
      if (episode.textHash == null) {
        await _repository.updateEpisodeTextHash(_episodeId!, _textHash!);
      }
    }

    _segments = TtsEditSegment.mergeSegments(
      originalSegments: originalSegments,
      dbSegments: dbSegments,
    );

    // Apply dictionary to ungenerated segments so the edit screen shows
    // the dictionary-converted text from the start.
    final dict = _dictionaryRepository;
    if (dict != null) {
      final entries = await dict.getEntriesSortedByLength();
      if (entries.isNotEmpty) {
        for (final segment in _segments) {
          if (!segment.dbRecordExists) {
            segment.text = TtsDictionaryRepository.applyDictionaryWithEntries(
                entries, segment.text);
          }
        }
      }
    }
  }

  Future<void> updateSegmentText(int segmentIndex, String newText) async {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return;

    final segment = _segments[segmentIndex];
    segment.text = newText;

    await _ensureEpisodeExists();

    if (segment.dbRecordExists) {
      await _repository.updateSegmentText(_episodeId!, segmentIndex, newText);
    } else {
      await _repository.insertSegment(
        episodeId: _episodeId!,
        segmentIndex: segmentIndex,
        text: newText,
        textOffset: segment.textOffset,
        textLength: segment.textLength,
      );
      segment.dbRecordExists = true;
    }
    segment.hasAudio = false;
  }

  Future<void> updateSegmentRefWavPath(
      int segmentIndex, String? refWavPath) async {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return;

    final segment = _segments[segmentIndex];
    segment.refWavPath = refWavPath;

    await _ensureEpisodeExists();

    if (segment.dbRecordExists) {
      await _repository.updateSegmentRefWavPath(
          _episodeId!, segmentIndex, refWavPath);
    } else {
      await _repository.insertSegment(
        episodeId: _episodeId!,
        segmentIndex: segmentIndex,
        text: segment.text,
        textOffset: segment.textOffset,
        textLength: segment.textLength,
        refWavPath: refWavPath,
      );
      segment.dbRecordExists = true;
    }
  }

  Future<void> updateSegmentMemo(int segmentIndex, String? memo) async {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return;

    final segment = _segments[segmentIndex];
    segment.memo = memo;

    await _ensureEpisodeExists();

    if (segment.dbRecordExists) {
      await _repository.updateSegmentMemo(_episodeId!, segmentIndex, memo);
    } else {
      await _repository.insertSegment(
        episodeId: _episodeId!,
        segmentIndex: segmentIndex,
        text: segment.text,
        textOffset: segment.textOffset,
        textLength: segment.textLength,
      );
      segment.dbRecordExists = true;
      await _repository.updateSegmentMemo(_episodeId!, segmentIndex, memo);
    }
  }

  Future<bool> _ensureModelLoaded(TtsEngineConfig config) async {
    return _session.ensureModelLoaded(config);
  }

  Future<bool> generateSegment({
    required int segmentIndex,
    required TtsEngineConfig config,
  }) async {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return false;
    final dict = _dictionaryRepository;
    final entries = dict != null
        ? await dict.getEntriesSortedByLength()
        : null;
    final fallbackRefWavPath = config is Qwen3EngineConfig
        ? config.refWavPath
        : null;
    final refWavPath = TtsRefWavResolver.resolve(
      storedPath: _segments[segmentIndex].refWavPath,
      fallbackPath: fallbackRefWavPath,
    );
    return _generateSegmentWithEntries(
      segmentIndex: segmentIndex,
      config: config,
      refWavPath: refWavPath,
      dictEntries: entries,
    );
  }

  Future<bool> _generateSegmentWithEntries({
    required int segmentIndex,
    required TtsEngineConfig config,
    String? refWavPath,
    List<TtsDictionaryEntry>? dictEntries,
  }) async {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return false;

    if (!await _ensureModelLoaded(config)) return false;

    final segment = _segments[segmentIndex];
    // For new segments, apply dictionary before synthesizing and storing.
    // For segments already in DB, use their stored text as-is (already converted).
    final synthText = !segment.dbRecordExists && dictEntries != null
        ? TtsDictionaryRepository.applyDictionaryWithEntries(
            dictEntries, segment.text)
        : segment.text;
    final result = await _synthesize(synthText, refWavPath);
    if (result == null) return false;

    final wavBytes = WavWriter.toBytes(
      audio: result.audio!,
      sampleRate: result.sampleRate,
    );

    await _ensureEpisodeExists();

    if (segment.dbRecordExists) {
      await _repository.updateSegmentAudio(
          _episodeId!, segmentIndex, wavBytes, result.audio!.length);
    } else {
      await _repository.insertSegment(
        episodeId: _episodeId!,
        segmentIndex: segmentIndex,
        text: synthText,
        textOffset: segment.textOffset,
        textLength: segment.textLength,
        audioData: wavBytes,
        sampleCount: result.audio!.length,
        refWavPath: segment.refWavPath,
      );
      segment.dbRecordExists = true;
    }

    // Keep in-memory text in sync with what was stored to DB.
    segment.text = synthText;
    segment.hasAudio = true;
    onSegmentGenerated?.call(segmentIndex);
    return true;
  }

  Future<void> generateAllUngenerated({
    required TtsEngineConfig config,
    String Function(String fileName)? resolveRefWavPath,
    void Function(int segmentIndex)? onSegmentStart,
  }) async {
    _cancelled = false;
    final ungenerated = <int>[];
    for (var i = 0; i < _segments.length; i++) {
      if (!_segments[i].hasAudio) {
        ungenerated.add(i);
      }
    }

    if (ungenerated.isEmpty) return;

    // Pre-load dictionary entries once to avoid N+1 DB queries in the segment loop.
    final dictRepo = _dictionaryRepository;
    final dictEntries = dictRepo != null
        ? await dictRepo.getEntriesSortedByLength()
        : null;

    final globalRefWavPath = switch (config) {
      Qwen3EngineConfig(:final refWavPath) => refWavPath,
      PiperEngineConfig() => null,
    };

    for (var idx = 0; idx < ungenerated.length; idx++) {
      if (_cancelled) break;

      final segmentIndex = ungenerated[idx];
      onSegmentStart?.call(segmentIndex);
      final segment = _segments[segmentIndex];
      final refWavPath = TtsRefWavResolver.resolve(
        storedPath: segment.refWavPath,
        fallbackPath: globalRefWavPath,
        resolver: resolveRefWavPath,
      );

      final success = await _generateSegmentWithEntries(
        segmentIndex: segmentIndex,
        config: config,
        refWavPath: refWavPath,
        dictEntries: dictEntries,
      );

      if (!success) break;

      onProgress?.call(idx + 1, ungenerated.length);
    }
  }

  Future<void> playSegment(int segmentIndex) async {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return;
    if (!_segments[segmentIndex].hasAudio || _episodeId == null) return;

    final segmentData =
        await _repository.getSegmentByIndex(_episodeId!, segmentIndex);
    final audioData = segmentData.audioData;
    if (audioData == null) return;

    final filePath = '$tempDirPath/tts_edit_preview_$segmentIndex.wav';
    await File(filePath).writeAsBytes(audioData);
    _writtenFiles.add(filePath);

    // isLast: false so SegmentPlayer ends with pause() rather than letting the
    // platform's playing flag stay set — required to play another segment next
    // without destroying the underlying player via stop().
    await _segmentPlayer.playSegment(filePath, isLast: false);
  }

  Future<void> playAll({void Function(int)? onSegmentStart}) async {
    _cancelled = false;
    for (var i = 0; i < _segments.length; i++) {
      if (_cancelled) break;
      if (!_segments[i].hasAudio) continue;
      onSegmentStart?.call(i);
      await playSegment(i);
    }
  }

  Future<void> stopPlayback() async {
    _cancelled = true;
    // interrupt() (not stop()) so the user can press preview again on the
    // same dialog — terminal stop is reserved for dispose().
    await _segmentPlayer.interrupt();
  }

  Future<void> resetSegment(int segmentIndex) async {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return;

    final segment = _segments[segmentIndex];

    if (segment.dbRecordExists && _episodeId != null) {
      await _repository.deleteSegment(_episodeId!, segmentIndex);
    }

    // Restore to dictionary-converted original, so users always see the
    // TTS-ready text rather than the raw novel text after resetting.
    final dict = _dictionaryRepository;
    if (dict != null) {
      final entries = await dict.getEntriesSortedByLength();
      segment.text = TtsDictionaryRepository.applyDictionaryWithEntries(
          entries, segment.originalText);
    } else {
      segment.text = segment.originalText;
    }
    segment.hasAudio = false;
    segment.refWavPath = null;
    segment.memo = null;
    segment.dbRecordExists = false;

    await _updateEpisodeStatusAfterReset();
  }

  Future<void> resetAll() async {
    if (_episodeId != null) {
      // Delete all segments for this episode
      for (var i = 0; i < _segments.length; i++) {
        if (_segments[i].dbRecordExists) {
          await _repository.deleteSegment(_episodeId!, i);
        }
      }
    }

    // Pre-load dictionary entries once for all resets.
    final dict = _dictionaryRepository;
    final dictEntries = dict != null ? await dict.getEntriesSortedByLength() : null;

    for (final segment in _segments) {
      segment.text = dictEntries != null
          ? TtsDictionaryRepository.applyDictionaryWithEntries(
              dictEntries, segment.originalText)
          : segment.originalText;
      segment.hasAudio = false;
      segment.refWavPath = null;
      segment.memo = null;
      segment.dbRecordExists = false;
    }

    await _updateEpisodeStatusAfterReset();
  }

  Future<void> cancel() async {
    _cancelled = true;
    _session.abort();
    await _session.dispose();
    // Replace the session so a subsequent generateSegment can reload the model.
    _session = TtsSession(isolate: _ttsIsolateFactory());
  }

  Future<void> dispose() async {
    _cancelled = true;
    _session.abort();
    await _session.dispose();
    await _cleanupFiles();
  }

  Future<void> _updateEpisodeStatusAfterReset() async {
    if (_episodeId == null) return;

    final hasAnyDbRecord = _segments.any((s) => s.dbRecordExists);
    if (!hasAnyDbRecord) {
      await _repository.deleteEpisode(_episodeId!);
      _episodeId = null;
    } else {
      final allHaveAudio = _segments.every((s) => s.hasAudio);
      final status = allHaveAudio
          ? TtsEpisodeStatus.completed
          : TtsEpisodeStatus.partial;
      await _repository.updateEpisodeStatus(_episodeId!, status);
    }
  }

  Future<void> _ensureEpisodeExists() async {
    if (_episodeId != null) return;

    _episodeId = await _repository.createEpisode(
      fileName: _fileName ?? 'unknown',
      sampleRate: _sampleRate,
      status: TtsEpisodeStatus.partial,
      textHash: _textHash,
    );
  }

  Future<SynthesisResultResponse?> _synthesize(
      String text, String? refWavPath) async {
    final result =
        await _session.synthesize(text: text, refWavPath: refWavPath);
    if (result == null) {
      onError?.call('Synthesis failed');
    }
    return result;
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
