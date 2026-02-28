import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'text_segmenter.dart';
import 'tts_audio_repository.dart';
import 'tts_edit_segment.dart';
import 'tts_isolate.dart';
import 'tts_playback_controller.dart';
import 'wav_writer.dart';

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
  })  : _ttsIsolate = ttsIsolate,
        _audioPlayer = audioPlayer,
        _repository = repository,
        _ttsIsolateFactory = ttsIsolateFactory ?? TtsIsolate.new;

  TtsIsolate _ttsIsolate;
  final TtsIsolate Function() _ttsIsolateFactory;
  final TtsAudioPlayer _audioPlayer;
  final TtsAudioRepository _repository;
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
    List<Map<String, Object?>> dbSegments = [];

    if (episode != null) {
      _episodeId = episode['id'] as int;
      dbSegments = await _repository.getSegments(_episodeId!);

      // Backfill text_hash for episodes created before this fix
      final storedHash = episode['text_hash'] as String?;
      if (storedHash == null) {
        await _repository.updateEpisodeTextHash(_episodeId!, _textHash!);
      }
    }

    _segments = TtsEditSegment.mergeSegments(
      originalSegments: originalSegments,
      dbSegments: dbSegments,
    );
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

  Future<bool> _ensureModelLoaded(String modelDir) async {
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

    _ttsIsolate.loadModel(modelDir);

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
    String? refWavPath,
  }) async {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return false;

    if (!await _ensureModelLoaded(modelDir)) return false;

    final segment = _segments[segmentIndex];
    final result = await _synthesize(segment.text, refWavPath);
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
        text: segment.text,
        textOffset: segment.textOffset,
        textLength: segment.textLength,
        audioData: wavBytes,
        sampleCount: result.audio!.length,
        refWavPath: refWavPath,
      );
      segment.dbRecordExists = true;
    }

    segment.hasAudio = true;
    onSegmentGenerated?.call(segmentIndex);
    return true;
  }

  Future<void> generateAllUngenerated({
    required String modelDir,
    String? globalRefWavPath,
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

    for (var idx = 0; idx < ungenerated.length; idx++) {
      if (_cancelled) break;

      final segmentIndex = ungenerated[idx];
      onSegmentStart?.call(segmentIndex);
      final segment = _segments[segmentIndex];
      final segmentRef = segment.refWavPath;
      // null → fall back to global, '' → no reference audio ("なし"), path → resolve via callback
      final refWavPath = switch (segmentRef) {
        null => globalRefWavPath,
        '' => null,
        _ => resolveRefWavPath != null ? resolveRefWavPath(segmentRef) : segmentRef,
      };

      final success = await generateSegment(
        segmentIndex: segmentIndex,
        modelDir: modelDir,
        refWavPath: refWavPath,
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
    final audioData = segmentData['audio_data'] as List<int>;

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
    await _audioPlayer.stop();
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

    segment.text = segment.originalText;
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

    for (final segment in _segments) {
      segment.text = segment.originalText;
      segment.hasAudio = false;
      segment.refWavPath = null;
      segment.memo = null;
      segment.dbRecordExists = false;
    }

    await _updateEpisodeStatusAfterReset();
  }

  Future<void> cancel() async {
    _cancelled = true;
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
      final status = allHaveAudio ? 'completed' : 'partial';
      await _repository.updateEpisodeStatus(_episodeId!, status);
    }
  }

  Future<void> _ensureEpisodeExists() async {
    if (_episodeId != null) return;

    _episodeId = await _repository.createEpisode(
      fileName: _fileName ?? 'unknown',
      sampleRate: _sampleRate,
      status: 'partial',
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
