import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_isolate.dart';
import 'package:novel_viewer/features/tts/data/tts_playback_controller.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';

// Fake TtsIsolate for testing
class FakeTtsIsolate implements TtsIsolate {
  FakeTtsIsolate({this.modelLoadSuccess = true});

  final _responseController = StreamController<TtsIsolateResponse>.broadcast();
  final bool modelLoadSuccess;
  bool spawned = false;
  bool disposed = false;
  String? loadedModelDir;
  final synthesizeRequests = <String>[];

  @override
  Stream<TtsIsolateResponse> get responses => _responseController.stream;

  @override
  Future<void> spawn() async {
    spawned = true;
  }

  @override
  void loadModel(String modelDir, {int nThreads = 4}) {
    loadedModelDir = modelDir;
    // Simulate async response
    Future.microtask(() {
      if (modelLoadSuccess) {
        _responseController.add(ModelLoadedResponse(success: true));
      } else {
        _responseController.add(
            ModelLoadedResponse(success: false, error: 'Model not found'));
      }
    });
  }

  @override
  void synthesize(String text, {String? refWavPath}) {
    synthesizeRequests.add(text);
    // Simulate async response with audio data
    Future.microtask(() {
      _responseController.add(SynthesisResultResponse(
        audio: Float32List.fromList([0.1, 0.2, 0.3]),
        sampleRate: 24000,
      ));
    });
  }

  @override
  void dispose() {
    disposed = true;
    _responseController.close();
  }

  void emitResponse(TtsIsolateResponse response) {
    _responseController.add(response);
  }
}

// Fake AudioPlayer for testing
class FakeAudioPlayer implements TtsAudioPlayer {
  final _stateController = StreamController<TtsPlayerState>.broadcast();
  bool playing = false;
  bool disposed = false;
  String? currentFilePath;
  final playCount = <String>[];

  @override
  Stream<TtsPlayerState> get playerStateStream => _stateController.stream;

  @override
  Future<void> setFilePath(String path) async {
    currentFilePath = path;
  }

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> stop() async {
    playing = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _stateController.close();
  }

  void emitCompleted() {
    _stateController.add(TtsPlayerState.completed);
  }

  void emitPlaying() {
    _stateController.add(TtsPlayerState.playing);
  }
}

// Fake WAV writer
class FakeWavWriter implements TtsWavWriter {
  final writtenFiles = <String>[];

  @override
  Future<void> write({
    required String path,
    required Float32List audio,
    required int sampleRate,
  }) async {
    writtenFiles.add(path);
  }
}

// Fake file cleaner
class FakeFileCleaner implements TtsFileCleaner {
  final deletedFiles = <String>[];

  @override
  Future<void> deleteFile(String path) async {
    deletedFiles.add(path);
  }
}

/// Audio player where play() blocks until emitCompleted() is called,
/// simulating just_audio's real behavior.
class BlockingFakeAudioPlayer implements TtsAudioPlayer {
  final _stateController = StreamController<TtsPlayerState>.broadcast();
  Completer<void>? _playCompleter;
  String? currentFilePath;
  final playedFiles = <String>[];
  bool disposed = false;

  @override
  Stream<TtsPlayerState> get playerStateStream => _stateController.stream;

  @override
  Future<void> setFilePath(String path) async {
    currentFilePath = path;
  }

  @override
  Future<void> play() {
    playedFiles.add(currentFilePath!);
    _playCompleter = Completer<void>();
    return _playCompleter!.future;
  }

  @override
  Future<void> stop() async {
    _playCompleter?.complete();
    _playCompleter = null;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _playCompleter?.complete();
    await _stateController.close();
  }

  void emitCompleted() {
    _stateController.add(TtsPlayerState.completed);
    _playCompleter?.complete();
    _playCompleter = null;
  }
}

/// Audio player where play() fails with an error.
class ErrorOnPlayAudioPlayer implements TtsAudioPlayer {
  final _stateController = StreamController<TtsPlayerState>.broadcast();
  bool disposed = false;

  @override
  Stream<TtsPlayerState> get playerStateStream => _stateController.stream;

  @override
  Future<void> setFilePath(String path) async {}

  @override
  Future<void> play() => Future.error(Exception('Playback error'));

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await _stateController.close();
  }
}

void main() {
  late ProviderContainer container;
  late FakeTtsIsolate fakeIsolate;
  late FakeAudioPlayer fakePlayer;
  late FakeWavWriter fakeWavWriter;
  late FakeFileCleaner fakeCleaner;
  late TtsPlaybackController controller;

  setUp(() {
    container = ProviderContainer();
    fakeIsolate = FakeTtsIsolate();
    fakePlayer = FakeAudioPlayer();
    fakeWavWriter = FakeWavWriter();
    fakeCleaner = FakeFileCleaner();

    controller = TtsPlaybackController(
      ref: container,
      ttsIsolate: fakeIsolate,
      audioPlayer: fakePlayer,
      wavWriter: fakeWavWriter,
      fileCleaner: fakeCleaner,
      tempDirPath: '/tmp/tts_test',
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('TtsPlaybackController', () {
    test('start sets state to loading then playing', () async {
      final states = <TtsPlaybackState>[];
      container.listen(
        ttsPlaybackStateProvider,
        (_, next) => states.add(next),
        fireImmediately: false,
      );

      await controller.start(
        text: 'こんにちは。世界。',
        modelDir: '/models',
      );

      // Wait for async operations
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(states, contains(TtsPlaybackState.loading));
      expect(
        container.read(ttsPlaybackStateProvider),
        TtsPlaybackState.playing,
      );
    });

    test('start spawns isolate and loads model', () async {
      await controller.start(
        text: 'テスト文。',
        modelDir: '/models',
      );

      await Future.delayed(Duration.zero);

      expect(fakeIsolate.spawned, isTrue);
      expect(fakeIsolate.loadedModelDir, '/models');
    });

    test('start splits text and synthesizes first segment', () async {
      await controller.start(
        text: 'はじめの文。次の文。',
        modelDir: '/models',
      );

      // Wait for model load response and synthesis request
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(fakeIsolate.synthesizeRequests, isNotEmpty);
      expect(fakeIsolate.synthesizeRequests.first, 'はじめの文。');
    });

    test('start sets highlight range for current segment', () async {
      await controller.start(
        text: 'はじめの文。次の文。',
        modelDir: '/models',
      );

      // Wait for pipeline to proceed
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final range = container.read(ttsHighlightRangeProvider);
      expect(range, isNotNull);
      expect(range!.start, 0);
    });

    test('start with startOffset begins from correct segment', () async {
      await controller.start(
        text: 'はじめの文。次の文。最後の文。',
        modelDir: '/models',
        startOffset: 6,
      );

      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(fakeIsolate.synthesizeRequests.first, '次の文。');
    });

    test('stop resets state to stopped', () async {
      await controller.start(
        text: 'テスト。',
        modelDir: '/models',
      );

      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      await controller.stop();

      expect(
        container.read(ttsPlaybackStateProvider),
        TtsPlaybackState.stopped,
      );
      expect(container.read(ttsHighlightRangeProvider), isNull);
    });

    test('stop disposes isolate', () async {
      await controller.start(
        text: 'テスト。',
        modelDir: '/models',
      );

      await Future.delayed(Duration.zero);

      await controller.stop();

      expect(fakeIsolate.disposed, isTrue);
    });

    test('stop cleans up temp WAV files', () async {
      await controller.start(
        text: 'テスト。',
        modelDir: '/models',
      );

      // Wait for WAV to be written
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      await controller.stop();

      // Should have attempted to clean up written files
      expect(fakeCleaner.deletedFiles.length,
          greaterThanOrEqualTo(fakeWavWriter.writtenFiles.length));
    });

    test('handles synthesis error gracefully', () async {
      // Override synthesize to emit error
      final errorIsolate = FakeTtsIsolate();
      final errorController = TtsPlaybackController(
        ref: container,
        ttsIsolate: errorIsolate,
        audioPlayer: fakePlayer,
        wavWriter: fakeWavWriter,
        fileCleaner: fakeCleaner,
        tempDirPath: '/tmp/tts_test',
      );

      // Start will spawn and load model
      await errorController.start(
        text: 'テスト。',
        modelDir: '/models',
      );

      await Future.delayed(Duration.zero);

      // Now manually emit an error response for synthesis
      errorIsolate.emitResponse(SynthesisResultResponse(
        audio: null,
        sampleRate: 0,
        error: 'Synthesis failed',
      ));

      await Future.delayed(Duration.zero);

      expect(
        container.read(ttsPlaybackStateProvider),
        TtsPlaybackState.stopped,
      );
    });

    test('handles model load failure', () async {
      final failIsolate = FakeTtsIsolate(modelLoadSuccess: false);
      final failController = TtsPlaybackController(
        ref: container,
        ttsIsolate: failIsolate,
        audioPlayer: fakePlayer,
        wavWriter: fakeWavWriter,
        fileCleaner: fakeCleaner,
        tempDirPath: '/tmp/tts_test',
      );

      await failController.start(
        text: 'テスト。',
        modelDir: '/models',
      );

      await Future.delayed(Duration.zero);

      expect(
        container.read(ttsPlaybackStateProvider),
        TtsPlaybackState.stopped,
      );
    });
  });

  group('TtsPlaybackController - sequential playback', () {
    test('advances to next segment after playback completes', () async {
      await controller.start(
        text: 'はじめの文。次の文。',
        modelDir: '/models',
      );

      // Wait for first segment to be synthesized and played
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Simulate first segment playback completion
      fakePlayer.emitCompleted();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Should have synthesized second segment
      expect(fakeIsolate.synthesizeRequests.length, greaterThanOrEqualTo(2));
    });

    test('stops after last segment completes', () async {
      // Use single-sentence text
      await controller.start(
        text: '一つだけの文。',
        modelDir: '/models',
      );

      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Simulate playback completion
      fakePlayer.emitCompleted();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(
        container.read(ttsPlaybackStateProvider),
        TtsPlaybackState.stopped,
      );
    });
  });

  group('TtsPlaybackController - blocking play sequential playback', () {
    // These tests use BlockingFakeAudioPlayer which simulates just_audio's
    // real behavior where play() blocks until playback completes.

    late BlockingFakeAudioPlayer blockingPlayer;
    late FakeTtsIsolate blockingIsolate;
    late TtsPlaybackController blockingController;

    setUp(() {
      blockingPlayer = BlockingFakeAudioPlayer();
      blockingIsolate = FakeTtsIsolate();
      blockingController = TtsPlaybackController(
        ref: container,
        ttsIsolate: blockingIsolate,
        audioPlayer: blockingPlayer,
        wavWriter: fakeWavWriter,
        fileCleaner: fakeCleaner,
        tempDirPath: '/tmp/tts_test',
      );
    });

    Future<void> pumpEventQueue({int times = 10}) async {
      for (var i = 0; i < times; i++) {
        await Future.delayed(Duration.zero);
      }
    }

    test('second segment plays after first completes with blocking play',
        () async {
      await blockingController.start(
        text: 'はじめの文。次の文。',
        modelDir: '/models',
      );

      await pumpEventQueue();

      // First segment should be playing
      expect(blockingPlayer.playedFiles, hasLength(1));
      expect(blockingPlayer.playedFiles[0], contains('tts_segment_0'));

      // Simulate first segment completion
      blockingPlayer.emitCompleted();
      await pumpEventQueue();

      // Second segment should now be playing with correct file
      expect(blockingPlayer.playedFiles, hasLength(2));
      expect(blockingPlayer.playedFiles[1], contains('tts_segment_1'));

      // Highlight should be on second segment ("次の文。" starts at offset 6)
      final range = container.read(ttsHighlightRangeProvider);
      expect(range, isNotNull);
      expect(range!.start, 6);

      await blockingController.stop();
      await pumpEventQueue();
    });

    test('three segments play in correct sequence with blocking play',
        () async {
      await blockingController.start(
        text: 'はじめの文。次の文。最後の文。',
        modelDir: '/models',
      );

      await pumpEventQueue();

      // First segment playing
      expect(blockingPlayer.playedFiles, hasLength(1));

      // Complete first segment
      blockingPlayer.emitCompleted();
      await pumpEventQueue();

      // Second segment playing
      expect(blockingPlayer.playedFiles, hasLength(2));

      // Complete second segment
      blockingPlayer.emitCompleted();
      await pumpEventQueue();

      // Third segment playing
      expect(blockingPlayer.playedFiles, hasLength(3));
      expect(blockingPlayer.playedFiles[2], contains('tts_segment_2'));

      // Highlight on third segment
      final range = container.read(ttsHighlightRangeProvider);
      expect(range, isNotNull);
      expect(range!.start, 10); // "はじめの文。次の文。" = 10 chars

      await blockingController.stop();
      await pumpEventQueue();
    });

    test('prefetch starts before play completes', () async {
      await blockingController.start(
        text: 'はじめの文。次の文。',
        modelDir: '/models',
      );

      await pumpEventQueue();

      // First segment is playing (play() is blocking)
      expect(blockingPlayer.playedFiles, hasLength(1));

      // With fix: prefetch should have started for next segment immediately
      // With bug: only 1 synthesis request (no prefetch while play blocks)
      expect(blockingIsolate.synthesizeRequests, hasLength(2));
      expect(blockingIsolate.synthesizeRequests[0], 'はじめの文。');
      expect(blockingIsolate.synthesizeRequests[1], '次の文。');

      await blockingController.stop();
      await pumpEventQueue();
    });

    test('playback completes and stops after last segment', () async {
      await blockingController.start(
        text: 'はじめの文。次の文。',
        modelDir: '/models',
      );

      await pumpEventQueue();

      // Complete first segment
      blockingPlayer.emitCompleted();
      await pumpEventQueue();

      // Complete second (last) segment
      blockingPlayer.emitCompleted();
      await pumpEventQueue();

      // Should be stopped
      expect(
        container.read(ttsPlaybackStateProvider),
        TtsPlaybackState.stopped,
      );
      expect(container.read(ttsHighlightRangeProvider), isNull);
    });
  });

  group('TtsPlaybackController - play error handling', () {
    test('handles play() error gracefully', () async {
      final errorPlayer = ErrorOnPlayAudioPlayer();
      final errorController = TtsPlaybackController(
        ref: container,
        ttsIsolate: fakeIsolate,
        audioPlayer: errorPlayer,
        wavWriter: fakeWavWriter,
        fileCleaner: fakeCleaner,
        tempDirPath: '/tmp/tts_test',
      );

      await errorController.start(
        text: 'テスト。',
        modelDir: '/models',
      );

      // Wait for pipeline: model load → synthesis → writeAndPlay → play error
      for (var i = 0; i < 10; i++) {
        await Future.delayed(Duration.zero);
      }

      // Should have stopped gracefully instead of unhandled error
      expect(
        container.read(ttsPlaybackStateProvider),
        TtsPlaybackState.stopped,
      );
    });
  });
}
