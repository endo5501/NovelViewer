import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'text_segmenter.dart';
import 'tts_audio_repository.dart';
import 'tts_dictionary_repository.dart';
import 'tts_edit_segment.dart';
import 'tts_engine_type.dart';
import 'tts_isolate.dart';
import 'tts_language.dart';
import 'tts_playback_controller.dart';
import 'wav_writer.dart';
import '../domain/tts_episode_status.dart';
import '../domain/tts_ref_wav_resolver.dart';
import '../domain/tts_segment.dart';

class _CancelledException implements Exception {
  const _CancelledException();
}

class TtsEditController {
  TtsEditController({
    required TtsIsolate ttsIsolate,
    required TtsAudioPlayer audioPlayer,
    required TtsAudioRepository repository,
    required this.tempDirPath,
    TtsIsolate Function()? ttsIsolateFactory,
    TtsDictionaryRepository? dictionaryRepository,
  })  : _ttsIsolate = ttsIsolate,
        _audioPlayer = audioPlayer,
        _repository = repository,
        _ttsIsolateFactory = ttsIsolateFactory ?? TtsIsolate.new,
        _dictionaryRepository = dictionaryRepository;

  TtsIsolate _ttsIsolate;
  final TtsIsolate Function() _ttsIsolateFactory;
  final TtsAudioPlayer _audioPlayer;
  final TtsAudioRepository _repository;
  final TtsDictionaryRepository? _dictionaryRepository;
  final String tempDirPath;
  final _textSegmenter = TextSegmenter();

  List<TtsEditSegment> _segments = [];
  List<TtsEditSegment> get segments => _segments;

  bool _modelLoaded = false;
  bool get modelLoaded => _modelLoaded;

  bool _cancelled = false;
  bool _isolateSpawned = false;
  int? _episodeId;
  String? _fileName;
  String? _textHash;
  int _sampleRate = 24000;
  StreamSubscription<TtsIsolateResponse>? _subscription;
  Completer<void>? _activePlayCompleter;
  Completer<SynthesisResultResponse>? _activeSynthesisCompleter;
  Completer<bool>? _activeModelLoadCompleter;
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

  Future<bool> _ensureModelLoaded(
    String modelDir, {
    TtsEngineType engineType = TtsEngineType.qwen3,
    int languageId = TtsLanguage.defaultLanguageId,
    String? dicDir,
    double? lengthScale,
    double? noiseScale,
    double? noiseW,
    String? embeddingCacheDir,
  }) async {
    if (_modelLoaded) return true;

    await _ttsIsolate.spawn();
    _isolateSpawned = true;

    final completer = Completer<bool>();
    _activeModelLoadCompleter = completer;

    _subscription = _ttsIsolate.responses.listen((response) {
      if (response is ModelLoadedResponse && !completer.isCompleted) {
        completer.complete(response.success);
        if (!response.success) {
          onError?.call('Model load failed: ${response.error}');
        }
      }
    });

    _ttsIsolate.loadModel(
      modelDir,
      engineType: engineType,
      languageId: languageId,
      dicDir: dicDir,
      lengthScale: lengthScale,
      noiseScale: noiseScale,
      noiseW: noiseW,
      embeddingCacheDir: embeddingCacheDir,
    );

    try {
      _modelLoaded = await completer.future;
      return _modelLoaded;
    } on _CancelledException {
      return false;
    } finally {
      _activeModelLoadCompleter = null;
    }
  }

  Future<bool> generateSegment({
    required int segmentIndex,
    required String modelDir,
    TtsEngineType engineType = TtsEngineType.qwen3,
    String? refWavPath,
    int languageId = TtsLanguage.defaultLanguageId,
    String? dicDir,
    double? lengthScale,
    double? noiseScale,
    double? noiseW,
    String? embeddingCacheDir,
  }) async {
    final dict = _dictionaryRepository;
    final entries = dict != null
        ? await dict.getEntriesSortedByLength()
        : null;
    return _generateSegmentWithEntries(
      segmentIndex: segmentIndex,
      modelDir: modelDir,
      engineType: engineType,
      refWavPath: refWavPath,
      languageId: languageId,
      dictEntries: entries,
      dicDir: dicDir,
      lengthScale: lengthScale,
      noiseScale: noiseScale,
      noiseW: noiseW,
      embeddingCacheDir: embeddingCacheDir,
    );
  }

  Future<bool> _generateSegmentWithEntries({
    required int segmentIndex,
    required String modelDir,
    TtsEngineType engineType = TtsEngineType.qwen3,
    String? refWavPath,
    int languageId = TtsLanguage.defaultLanguageId,
    List<TtsDictionaryEntry>? dictEntries,
    String? dicDir,
    double? lengthScale,
    double? noiseScale,
    double? noiseW,
    String? embeddingCacheDir,
  }) async {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return false;

    if (!await _ensureModelLoaded(modelDir, engineType: engineType, languageId: languageId, dicDir: dicDir, lengthScale: lengthScale, noiseScale: noiseScale, noiseW: noiseW, embeddingCacheDir: embeddingCacheDir)) return false;

    final segment = _segments[segmentIndex];
    // For new segments, apply dictionary before synthesizing and storing.
    // For segments already in DB, use their stored text as-is (already converted).
    final synthText = !segment.dbRecordExists && dictEntries != null
        ? TtsDictionaryRepository.applyDictionaryWithEntries(dictEntries, segment.text)
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
    required String modelDir,
    TtsEngineType engineType = TtsEngineType.qwen3,
    String? globalRefWavPath,
    int languageId = TtsLanguage.defaultLanguageId,
    String Function(String fileName)? resolveRefWavPath,
    void Function(int segmentIndex)? onSegmentStart,
    String? dicDir,
    double? lengthScale,
    double? noiseScale,
    double? noiseW,
    String? embeddingCacheDir,
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
        modelDir: modelDir,
        engineType: engineType,
        refWavPath: refWavPath,
        languageId: languageId,
        dictEntries: dictEntries,
        dicDir: dicDir,
        lengthScale: lengthScale,
        noiseScale: noiseScale,
        noiseW: noiseW,
        embeddingCacheDir: embeddingCacheDir,
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

    await _audioPlayer.setFilePath(filePath);

    final playCompleter = Completer<void>();
    _activePlayCompleter = playCompleter;
    late StreamSubscription<TtsPlayerState> playSub;
    playSub = _audioPlayer.playerStateStream.listen((state) {
      if (state == TtsPlayerState.completed && !playCompleter.isCompleted) {
        playCompleter.complete();
      }
    });

    await _audioPlayer.play();
    await playCompleter.future;
    _activePlayCompleter = null;
    await playSub.cancel();
    // Use pause() instead of stop() to reset _playing flag without
    // destroying the platform (which would kill buffered audio output).
    await _audioPlayer.pause();
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
    final completer = _activePlayCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _activePlayCompleter = null;
    await _audioPlayer.stop();
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
    _ttsIsolate.abort();
    if (!(_activeModelLoadCompleter?.isCompleted ?? true)) {
      _activeModelLoadCompleter!.completeError(const _CancelledException());
    }
    if (!(_activeSynthesisCompleter?.isCompleted ?? true)) {
      _activeSynthesisCompleter!.completeError(const _CancelledException());
    }
    await _teardownIsolate(recreate: true);
  }

  Future<void> dispose() async {
    _cancelled = true;
    _ttsIsolate.abort();
    await _teardownIsolate(recreate: false);
    await _cleanupFiles();
  }

  Future<void> _teardownIsolate({required bool recreate}) async {
    await _subscription?.cancel();
    _subscription = null;
    if (_isolateSpawned || _modelLoaded) {
      await _ttsIsolate.dispose();
      if (recreate) _ttsIsolate = _ttsIsolateFactory();
    }
    _isolateSpawned = false;
    _modelLoaded = false;
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
    final completer = Completer<SynthesisResultResponse>();
    _activeSynthesisCompleter = completer;

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
        onError?.call('Synthesis failed: ${result.error}');
        return null;
      }

      return result;
    } on _CancelledException {
      return null;
    } finally {
      _activeSynthesisCompleter = null;
      await sub.cancel();
    }
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
