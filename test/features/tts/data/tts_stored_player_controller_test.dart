import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/data/tts_playback_controller.dart';
import 'package:novel_viewer/features/tts/data/tts_stored_player_controller.dart';
import 'package:novel_viewer/features/tts/data/wav_writer.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fake audio player for testing stored playback.
class FakeAudioPlayer implements TtsAudioPlayer {
  final _stateController = StreamController<TtsPlayerState>.broadcast();
  String? currentFilePath;
  bool isPlaying = false;
  bool isPaused = false;
  bool isDisposed = false;

  @override
  Stream<TtsPlayerState> get playerStateStream => _stateController.stream;

  @override
  Future<void> setFilePath(String path) async {
    currentFilePath = path;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    isPaused = false;
    _stateController.add(TtsPlayerState.playing);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    isPaused = true;
    _stateController.add(TtsPlayerState.paused);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    isPaused = false;
    _stateController.add(TtsPlayerState.stopped);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    _stateController.close();
  }

  void simulateCompletion() {
    isPlaying = false;
    _stateController.add(TtsPlayerState.completed);
  }
}

Uint8List _makeWavBytes() {
  return WavWriter.toBytes(
    audio: Float32List.fromList([0.1, 0.2, 0.3, 0.4, 0.5]),
    sampleRate: 24000,
  );
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
    tempDir = Directory.systemTemp.createTempSync('tts_stored_player_test_');
    database = TtsAudioDatabase(tempDir.path);
    repository = TtsAudioRepository(database);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    tempDir.deleteSync(recursive: true);
  });

  /// Helper to create an episode with segments in the DB.
  Future<int> createTestEpisode({int segmentCount = 3}) async {
    final episodeId = await repository.createEpisode(
      fileName: '0001_テスト.txt',
      sampleRate: 24000,
      status: 'completed',
    );
    for (var i = 0; i < segmentCount; i++) {
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: i,
        text: 'テスト文$i。',
        textOffset: i * 6,
        textLength: 5,
        audioData: _makeWavBytes(),
        sampleCount: 5,
      );
    }
    return episodeId;
  }

  group('TtsStoredPlayerController', () {
    test('plays all segments in order', () async {
      final episodeId = await createTestEpisode(segmentCount: 3);
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(episodeId: episodeId);

      // First segment should be playing
      expect(player.isPlaying, isTrue);
      expect(player.currentFilePath, isNotNull);

      // Simulate completion of each segment and wait for next to start
      player.simulateCompletion();
      await _pumpUntil(() => player.isPlaying);

      expect(player.isPlaying, isTrue); // second segment playing

      player.simulateCompletion();
      await _pumpUntil(() => player.isPlaying);

      expect(player.isPlaying, isTrue); // third segment playing

      player.simulateCompletion();
      await _pumpUntil(
          () => container.read(ttsPlaybackStateProvider) == TtsPlaybackState.stopped);

      // All done - should be stopped
      final state = container.read(ttsPlaybackStateProvider);
      expect(state, TtsPlaybackState.stopped);
    });

    test('updates highlight range for each segment', () async {
      final episodeId = await createTestEpisode(segmentCount: 2);
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(episodeId: episodeId);

      // Check first segment highlight
      final highlight1 = container.read(ttsHighlightRangeProvider);
      expect(highlight1, isNotNull);
      expect(highlight1!.start, 0);
      expect(highlight1.end, 5);

      // Move to second segment
      player.simulateCompletion();
      await _pumpUntil(() {
        final h = container.read(ttsHighlightRangeProvider);
        return h != null && h.start == 6;
      });

      final highlight2 = container.read(ttsHighlightRangeProvider);
      expect(highlight2, isNotNull);
      expect(highlight2!.start, 6);
      expect(highlight2.end, 11);

      // Clean up to prevent async leaks
      await controller.stop();
    });

    test('supports pause and resume', () async {
      final episodeId = await createTestEpisode();
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(episodeId: episodeId);
      expect(container.read(ttsPlaybackStateProvider), TtsPlaybackState.playing);

      // Pause
      await controller.pause();
      expect(player.isPaused, isTrue);
      expect(container.read(ttsPlaybackStateProvider), TtsPlaybackState.paused);

      // Resume
      await controller.resume();
      expect(player.isPlaying, isTrue);
      expect(container.read(ttsPlaybackStateProvider), TtsPlaybackState.playing);
    });

    test('stop resets state and clears highlight', () async {
      final episodeId = await createTestEpisode();
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(episodeId: episodeId);

      await controller.stop();

      expect(container.read(ttsPlaybackStateProvider), TtsPlaybackState.stopped);
      expect(container.read(ttsHighlightRangeProvider), isNull);
    });

    test('starts from segment matching text offset', () async {
      final episodeId = await createTestEpisode(segmentCount: 3);
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      // Start from offset 6 which should match segment 1
      await controller.start(episodeId: episodeId, startOffset: 6);

      // Should be playing segment 1, not segment 0
      final highlight = container.read(ttsHighlightRangeProvider);
      expect(highlight, isNotNull);
      expect(highlight!.start, 6);
    });

    test('starts from segment 0 when no offset specified', () async {
      final episodeId = await createTestEpisode();
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(episodeId: episodeId);

      final highlight = container.read(ttsHighlightRangeProvider);
      expect(highlight, isNotNull);
      expect(highlight!.start, 0);
    });

    test('cleans up temporary files on stop', () async {
      final episodeId = await createTestEpisode(segmentCount: 1);
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(episodeId: episodeId);

      // A temp file should exist
      final tempFiles = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.wav'));
      expect(tempFiles, isNotEmpty);

      await controller.stop();

      // Temp files should be cleaned up
      final remainingTempFiles = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.wav'));
      expect(remainingTempFiles, isEmpty);
    });

    test('stop during pause works correctly', () async {
      final episodeId = await createTestEpisode();
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
      );

      await controller.start(episodeId: episodeId);
      await controller.pause();
      await controller.stop();

      expect(container.read(ttsPlaybackStateProvider), TtsPlaybackState.stopped);
      expect(container.read(ttsHighlightRangeProvider), isNull);
    });
  });
}

/// Pumps the event loop until [condition] returns true, with a timeout.
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
