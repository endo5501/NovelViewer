import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';
import 'package:novel_viewer/features/tts/data/tts_isolate.dart';
import 'package:novel_viewer/features/tts/data/tts_playback_controller.dart';
import 'package:novel_viewer/features/tts/data/tts_streaming_controller.dart';
import 'package:novel_viewer/features/tts/data/wav_writer.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fake TtsIsolate that auto-responds to synthesis requests.
class _FakeTtsIsolate implements TtsIsolate {
  final _responseController =
      StreamController<TtsIsolateResponse>.broadcast();
  bool spawned = false;
  bool disposed = false;
  final synthesizeRequests = <String>[];
  final synthesizeRefWavPaths = <String?>[];

  @override
  Stream<TtsIsolateResponse> get responses => _responseController.stream;

  @override
  Future<void> spawn() async {
    spawned = true;
  }

  @override
  void loadModel(String modelDir,
      {int nThreads = 4, int languageId = TtsEngine.languageJapanese}) {
    Future.microtask(() {
      _responseController.add(ModelLoadedResponse(success: true));
    });
  }

  @override
  void synthesize(String text, {String? refWavPath}) {
    synthesizeRequests.add(text);
    synthesizeRefWavPaths.add(refWavPath);
    Future.microtask(() {
      _responseController.add(SynthesisResultResponse(
        audio: Float32List.fromList([0.1, 0.2, 0.3]),
        sampleRate: 24000,
      ));
    });
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!_responseController.isClosed) {
      _responseController.close();
    }
  }
}

/// Fake audio player that auto-completes playback after a microtask delay.
class _AutoCompleteAudioPlayer implements TtsAudioPlayer {
  final _stateController = StreamController<TtsPlayerState>.broadcast();
  String? currentFilePath;
  bool isPlaying = false;
  bool isDisposed = false;
  final playedFiles = <String>[];

  @override
  Stream<TtsPlayerState> get playerStateStream => _stateController.stream;

  @override
  Future<void> setFilePath(String path) async {
    currentFilePath = path;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    playedFiles.add(currentFilePath!);
    _stateController.add(TtsPlayerState.playing);
    // Auto-complete after a short delay
    Future.delayed(const Duration(milliseconds: 10), () {
      if (isPlaying && !isDisposed) {
        isPlaying = false;
        _stateController.add(TtsPlayerState.completed);
      }
    });
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _stateController.add(TtsPlayerState.paused);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    _stateController.add(TtsPlayerState.stopped);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }
}

/// Fake audio player with manual completion control.
class _ManualAudioPlayer implements TtsAudioPlayer {
  final _stateController = StreamController<TtsPlayerState>.broadcast();
  String? currentFilePath;
  bool isPlaying = false;
  bool isDisposed = false;
  final playedFiles = <String>[];

  @override
  Stream<TtsPlayerState> get playerStateStream => _stateController.stream;

  @override
  Future<void> setFilePath(String path) async {
    currentFilePath = path;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    playedFiles.add(currentFilePath!);
    _stateController.add(TtsPlayerState.playing);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _stateController.add(TtsPlayerState.paused);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    _stateController.add(TtsPlayerState.stopped);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }

  void simulateCompletion() {
    isPlaying = false;
    _stateController.add(TtsPlayerState.completed);
  }
}

/// Fake audio player that throws on dispose to simulate cleanup failures.
class _ThrowingDisposeAudioPlayer extends _ManualAudioPlayer {
  @override
  Future<void> dispose() async {
    throw Exception('dispose failed: DB closed');
  }
}

/// Fake audio player that simulates just_audio's BehaviorSubject behavior:
/// new subscribers to playerStateStream immediately receive the latest state.
/// This is critical for catching bugs where a stale 'completed' state from
/// a previous segment causes the next segment to be skipped.
class _BehaviorSubjectAudioPlayer implements TtsAudioPlayer {
  TtsPlayerState _lastState = TtsPlayerState.stopped;
  final _emitCallbacks = <void Function(TtsPlayerState)>[];
  String? currentFilePath;
  bool isPlaying = false;
  bool isDisposed = false;
  final playedFiles = <String>[];

  void _emit(TtsPlayerState state) {
    _lastState = state;
    for (final cb in List.of(_emitCallbacks)) {
      cb(state);
    }
  }

  @override
  Stream<TtsPlayerState> get playerStateStream {
    // Use sync controller to simulate BehaviorSubject's synchronous replay
    final controller = StreamController<TtsPlayerState>(sync: true);
    controller.add(_lastState); // Delivered synchronously on listen
    void cb(TtsPlayerState state) {
      if (!controller.isClosed) controller.add(state);
    }
    _emitCallbacks.add(cb);
    controller.onCancel = () {
      _emitCallbacks.remove(cb);
      controller.close();
    };
    return controller.stream;
  }

  @override
  Future<void> setFilePath(String path) async {
    currentFilePath = path;
    // Simulate just_audio: setFilePath resets processingState to ready
    // but playing stays the same. Adapter maps ready+playing to 'playing'.
    if (_lastState == TtsPlayerState.completed) {
      _emit(TtsPlayerState.playing);
    }
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    playedFiles.add(currentFilePath!);
    _emit(TtsPlayerState.playing);
    Future.delayed(const Duration(milliseconds: 10), () {
      if (isPlaying && !isDisposed) {
        isPlaying = false;
        _emit(TtsPlayerState.completed);
      }
    });
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _emit(TtsPlayerState.paused);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    _emit(TtsPlayerState.stopped);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    _emitCallbacks.clear();
  }
}

Uint8List _makeWavBytes() {
  return WavWriter.toBytes(
    audio: Float32List.fromList([0.1, 0.2, 0.3, 0.4, 0.5]),
    sampleRate: 24000,
  );
}

String _computeTextHash(String text) {
  return sha256.convert(utf8.encode(text)).toString();
}

void main() {
  late Directory tempDir;
  late TtsAudioDatabase database;
  late TtsAudioRepository repository;
  late ProviderContainer container;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('tts_streaming_test_');
    database = TtsAudioDatabase(tempDir.path);
    repository = TtsAudioRepository(database);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    tempDir.deleteSync(recursive: true);
  });

  group('TtsStreamingController', () {
    test('fresh start: generates and plays all segments', () async {
      final isolate = _FakeTtsIsolate();
      final player = _AutoCompleteAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(
        text: '文1。文2。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // All segments should have been synthesized
      expect(isolate.synthesizeRequests, hasLength(2));

      // Episode should be completed
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode, isNotNull);
      expect(episode!['status'], 'completed');

      // Text hash should be stored
      expect(episode['text_hash'], isNotNull);
      expect(episode['text_hash'], _computeTextHash('文1。文2。'));

      // Segments should exist in DB
      final segments = await repository.getSegments(episode['id'] as int);
      expect(segments, hasLength(2));
    });

    test('play completed episode without generation', () async {
      // Pre-create completed episode with segments
      const text = '文1。文2。';
      final episodeId = await repository.createEpisode(
        fileName: '0001_テスト.txt',
        sampleRate: 24000,
        status: 'completed',
        textHash: _computeTextHash(text),
      );
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 0,
        text: '文1。',
        textOffset: 0,
        textLength: 3,
        audioData: _makeWavBytes(),
        sampleCount: 5,
      );
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 1,
        text: '文2。',
        textOffset: 3,
        textLength: 3,
        audioData: _makeWavBytes(),
        sampleCount: 5,
      );

      final isolate = _FakeTtsIsolate();
      final player = _AutoCompleteAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(
        text: text,
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // Should NOT have synthesized anything
      expect(isolate.synthesizeRequests, isEmpty);
      expect(isolate.spawned, isFalse);

      // Both segments should have been played
      expect(player.playedFiles, hasLength(2));
    });

    test('resume from partial episode: plays stored then generates remaining',
        () async {
      const text = '文1。文2。文3。';
      final episodeId = await repository.createEpisode(
        fileName: '0001_テスト.txt',
        sampleRate: 24000,
        status: 'partial',
        textHash: _computeTextHash(text),
      );
      // Only segment 0 is stored
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 0,
        text: '文1。',
        textOffset: 0,
        textLength: 3,
        audioData: _makeWavBytes(),
        sampleCount: 5,
      );

      final isolate = _FakeTtsIsolate();
      final player = _AutoCompleteAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(
        text: text,
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // Should have synthesized only segments 1 and 2 (skipped 0)
      expect(isolate.synthesizeRequests, hasLength(2));
      expect(isolate.synthesizeRequests[0], '文2。');
      expect(isolate.synthesizeRequests[1], '文3。');

      // All 3 segments should have been played
      expect(player.playedFiles, hasLength(3));

      // Episode should be completed
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode!['status'], 'completed');
    });

    test('text hash mismatch deletes existing data and starts fresh',
        () async {
      const oldText = '古いテキスト。';
      const newText = '新しいテキスト。';
      final episodeId = await repository.createEpisode(
        fileName: '0001_テスト.txt',
        sampleRate: 24000,
        status: 'completed',
        textHash: _computeTextHash(oldText),
      );
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 0,
        text: '古いテキスト。',
        textOffset: 0,
        textLength: 7,
        audioData: _makeWavBytes(),
        sampleCount: 5,
      );

      final isolate = _FakeTtsIsolate();
      final player = _AutoCompleteAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(
        text: newText,
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // Should have generated new text
      expect(isolate.synthesizeRequests, hasLength(1));
      expect(isolate.synthesizeRequests[0], '新しいテキスト。');

      // Episode should have new text hash
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode!['text_hash'], _computeTextHash(newText));
    });

    test('stop during streaming preserves data with partial status', () async {
      final isolate = _FakeTtsIsolate();
      final player = _ManualAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      // Start generation+playback in the background
      final future = controller.start(
        text: '文1。文2。文3。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // Wait for first segment to start playing
      await _pumpUntil(() => player.isPlaying);

      // Stop while playing
      await controller.stop();
      await future;

      // Episode should be partial (since not all segments completed playback)
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode, isNotNull);
      final status = episode!['status'] as String;
      expect(status == 'partial' || status == 'completed', isTrue);

      // Playback state should be stopped
      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.stopped);
      expect(container.read(ttsHighlightRangeProvider), isNull);
    });

    test('pause and resume during streaming', () async {
      final isolate = _FakeTtsIsolate();
      final player = _ManualAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      final future = controller.start(
        text: '文1。文2。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      await _pumpUntil(() => player.isPlaying);

      // Pause
      await controller.pause();
      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.paused);

      // Resume
      await controller.resume();
      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.playing);

      // Complete all segments to finish
      player.simulateCompletion();
      await _pumpUntil(() => player.isPlaying);
      player.simulateCompletion();
      await future;
    });

    test('highlight is set during playback', () async {
      final isolate = _FakeTtsIsolate();
      final player = _ManualAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      final future = controller.start(
        text: '文1。文2。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      await _pumpUntil(() => player.isPlaying);

      // Highlight should be set for first segment
      final highlight = container.read(ttsHighlightRangeProvider);
      expect(highlight, isNotNull);
      expect(highlight!.start, 0);

      // Stop to finish the test cleanly
      await controller.stop();
      await future;
    });

    test('plays all segments without skipping with BehaviorSubject stream',
        () async {
      // This test verifies the fix for a bug where just_audio's
      // BehaviorSubject-backed playerStateStream replays the 'completed' state
      // from the previous segment, causing every other segment to be skipped.
      final isolate = _FakeTtsIsolate();
      final player = _BehaviorSubjectAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(
        text: '文1。文2。文3。文4。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // All 4 segments must be played - no skipping
      expect(player.playedFiles, hasLength(4));

      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode!['status'], 'completed');
    });

    test('stop clears highlight and sets stopped state', () async {
      final isolate = _FakeTtsIsolate();
      final player = _ManualAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      final future = controller.start(
        text: '文1。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      await _pumpUntil(() => player.isPlaying);
      await controller.stop();
      await future;

      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.stopped);
      expect(container.read(ttsHighlightRangeProvider), isNull);
    });

    test('stop clears all state even when audioPlayer.dispose throws',
        () async {
      final isolate = _FakeTtsIsolate();
      final player = _ThrowingDisposeAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      final future = controller.start(
        text: '文1。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      await _pumpUntil(() => player.isPlaying);

      // Verify highlight is set before stop
      expect(container.read(ttsHighlightRangeProvider), isNotNull);

      // stop() should not throw even when dispose fails
      await controller.stop();
      await future;

      // All state must be cleared despite the exception
      expect(
          container.read(ttsPlaybackStateProvider), TtsPlaybackState.stopped);
      expect(container.read(ttsHighlightRangeProvider), isNull);
      expect(container.read(ttsGenerationProgressProvider).current, 0);
      expect(container.read(ttsGenerationProgressProvider).total, 0);
    });

    test('plays mixed generation state: some segments have audio, some do not',
        () async {
      // Simulate edit screen scenario: segment 0 and 2 have audio, 1 does not
      const text = '文1。文2。文3。';
      final episodeId = await repository.createEpisode(
        fileName: '0001_テスト.txt',
        sampleRate: 24000,
        status: 'partial',
        textHash: _computeTextHash(text),
      );
      // Segment 0: has audio
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 0,
        text: '文1。',
        textOffset: 0,
        textLength: 3,
        audioData: _makeWavBytes(),
        sampleCount: 5,
      );
      // Segment 1: edited text, no audio (from edit screen)
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 1,
        text: '編集済み文2。',
        textOffset: 3,
        textLength: 3,
      );
      // Segment 2: has audio
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 2,
        text: '文3。',
        textOffset: 6,
        textLength: 3,
        audioData: _makeWavBytes(),
        sampleCount: 5,
      );

      final isolate = _FakeTtsIsolate();
      final player = _AutoCompleteAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(
        text: text,
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // Should have synthesized only segment 1 (the one without audio)
      expect(isolate.synthesizeRequests, hasLength(1));
      expect(isolate.synthesizeRequests[0], '編集済み文2。');

      // All 3 segments should have been played
      expect(player.playedFiles, hasLength(3));

      // Episode should be completed
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode!['status'], 'completed');
    });

    test('on-demand generation uses DB text for edited segments', () async {
      const text = '山奥の一軒家。散歩に出かけよう。';
      final episodeId = await repository.createEpisode(
        fileName: '0001_テスト.txt',
        sampleRate: 24000,
        status: 'partial',
        textHash: _computeTextHash(text),
      );
      // Segment 0: edited text, no audio
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 0,
        text: '山奥のいっけんや。',
        textOffset: 0,
        textLength: 6,
      );
      // Segment 1: no DB record at all

      final isolate = _FakeTtsIsolate();
      final player = _AutoCompleteAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(
        text: text,
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // Both segments should be synthesized
      expect(isolate.synthesizeRequests, hasLength(2));
      // Segment 0: should use the edited text from DB
      expect(isolate.synthesizeRequests[0], '山奥のいっけんや。');
      // Segment 1: should use original text from TextSegmenter
      expect(isolate.synthesizeRequests[1], '散歩に出かけよう。');

      // Both should have been played
      expect(player.playedFiles, hasLength(2));
    });

    test('on-demand generation uses per-segment ref_wav_path', () async {
      const text = '文1。文2。';
      final episodeId = await repository.createEpisode(
        fileName: '0001_テスト.txt',
        sampleRate: 24000,
        status: 'partial',
        textHash: _computeTextHash(text),
      );
      // Segment 0: no audio, has per-segment ref_wav_path
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 0,
        text: '文1。',
        textOffset: 0,
        textLength: 3,
        refWavPath: '/voices/custom_voice.wav',
      );
      // Segment 1: no DB record, should use global ref_wav_path

      final isolate = _FakeTtsIsolate();
      final player = _AutoCompleteAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(
        text: text,
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
        refWavPath: '/voices/global_voice.wav',
      );

      // Both should be synthesized
      expect(isolate.synthesizeRequests, hasLength(2));
      // Segment 0: should use per-segment ref_wav_path
      expect(isolate.synthesizeRefWavPaths[0], '/voices/custom_voice.wav');
      // Segment 1: should use global ref_wav_path
      expect(isolate.synthesizeRefWavPaths[1], '/voices/global_voice.wav');
      // Verify playback happened
      expect(player.playedFiles, hasLength(2));
    });

    test('on-demand generation resolves ref_wav_path via callback', () async {
      const text = '文1。文2。';
      final episodeId = await repository.createEpisode(
        fileName: '0001_テスト.txt',
        sampleRate: 24000,
        status: 'partial',
        textHash: _computeTextHash(text),
      );
      // Segment 0: no audio, has per-segment ref_wav_path (filename only)
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 0,
        text: '文1。',
        textOffset: 0,
        textLength: 3,
        refWavPath: 'custom_voice.wav',
      );

      final isolate = _FakeTtsIsolate();
      final player = _AutoCompleteAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(
        text: text,
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
        refWavPath: '/full/path/to/voices/global_voice.wav',
        resolveRefWavPath: (fileName) => '/full/path/to/voices/$fileName',
      );

      expect(isolate.synthesizeRequests, hasLength(2));
      // Segment 0: filename resolved to full path via callback
      expect(isolate.synthesizeRefWavPaths[0],
          '/full/path/to/voices/custom_voice.wav');
      // Segment 1: no DB record, uses global ref_wav_path
      expect(isolate.synthesizeRefWavPaths[1],
          '/full/path/to/voices/global_voice.wav');
    });

    test('on-demand generation stores NULL ref_wav_path for new segments',
        () async {
      const text = '文1。文2。';

      final isolate = _FakeTtsIsolate();
      final player = _AutoCompleteAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(
        text: text,
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
        refWavPath: '/full/path/to/voices/global_voice.wav',
      );

      // Check that inserted segments have ref_wav_path = NULL
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      final segments = await repository.getSegments(episode!['id'] as int);
      expect(segments, hasLength(2));
      for (final segment in segments) {
        expect(segment['ref_wav_path'], isNull,
            reason: 'New segments should store NULL ref_wav_path, '
                'not the global full path');
      }
    });

    test('start from text offset plays from the matching segment', () async {
      const text = '文1。文2。文3。';
      final episodeId = await repository.createEpisode(
        fileName: '0001_テスト.txt',
        sampleRate: 24000,
        status: 'completed',
        textHash: _computeTextHash(text),
      );
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 0,
        text: '文1。',
        textOffset: 0,
        textLength: 3,
        audioData: _makeWavBytes(),
        sampleCount: 5,
      );
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 1,
        text: '文2。',
        textOffset: 3,
        textLength: 3,
        audioData: _makeWavBytes(),
        sampleCount: 5,
      );
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 2,
        text: '文3。',
        textOffset: 6,
        textLength: 3,
        audioData: _makeWavBytes(),
        sampleCount: 5,
      );

      final isolate = _FakeTtsIsolate();
      final player = _AutoCompleteAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(
        text: text,
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
        startOffset: 4, // Should match segment 1 (text_offset=3)
      );

      // Should play segments 1 and 2 (skipping segment 0)
      expect(player.playedFiles, hasLength(2));
      // No generation needed
      expect(isolate.synthesizeRequests, isEmpty);
    });

    test('on-demand generation treats empty ref_wav_path as no reference',
        () async {
      const text = '文1。文2。';
      final episodeId = await repository.createEpisode(
        fileName: '0001_テスト.txt',
        sampleRate: 24000,
        status: 'partial',
        textHash: _computeTextHash(text),
      );
      // Segment 0: has empty ref_wav_path (user chose "なし")
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 0,
        text: '文1。',
        textOffset: 0,
        textLength: 3,
        refWavPath: '',
      );
      // Segment 1: no DB record, should use global ref_wav_path

      final isolate = _FakeTtsIsolate();
      final player = _AutoCompleteAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(
        text: text,
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
        refWavPath: '/voices/global.wav',
      );

      expect(isolate.synthesizeRequests, hasLength(2));
      // Segment 0: empty ref_wav_path should become null (no reference)
      expect(isolate.synthesizeRefWavPaths[0], isNull);
      // Segment 1: should use global ref_wav_path
      expect(isolate.synthesizeRefWavPaths[1], '/voices/global.wav');
    });

    test('stop resets generation progress provider', () async {
      final isolate = _FakeTtsIsolate();
      final player = _ManualAudioPlayer();
      final controller = TtsStreamingController(
        ref: container,
        ttsIsolate: isolate,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      final future = controller.start(
        text: '文1。文2。文3。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // Wait for playback to start (generation sets progress)
      await _pumpUntil(() => player.isPlaying);

      // Verify progress was set during generation
      final progressBefore = container.read(ttsGenerationProgressProvider);
      expect(progressBefore.total, greaterThan(0));

      await controller.stop();
      await future;

      // Generation progress should be reset to zero
      final progressAfter = container.read(ttsGenerationProgressProvider);
      expect(progressAfter.current, 0);
      expect(progressAfter.total, 0);
    });
  });
}

Future<void> _pumpUntil(bool Function() condition,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future.delayed(const Duration(milliseconds: 1));
  }
}
