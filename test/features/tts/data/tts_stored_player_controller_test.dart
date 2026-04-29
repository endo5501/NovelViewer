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
import 'package:novel_viewer/features/tts/domain/tts_episode_status.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fake audio player for testing stored playback. play() does not auto-
/// complete; callers drive completion explicitly via [simulateCompletion].
class FakeAudioPlayer implements TtsAudioPlayer {
  final _stateController = StreamController<TtsPlayerState>.broadcast();
  String? currentFilePath;
  final playedFiles = <String>[];
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
    if (currentFilePath != null) playedFiles.add(currentFilePath!);
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
    if (!_stateController.isClosed) {
      await _stateController.close();
    }
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

Future<void> _pumpUntil(bool Function() condition,
    {Duration timeout = const Duration(seconds: 3)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future.delayed(const Duration(milliseconds: 1));
  }
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
      status: TtsEpisodeStatus.completed,
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
        bufferDrainDelay: Duration.zero,
      );

      // start() awaits all segments — run it in the background and drive
      // each segment to completion via simulateCompletion.
      final future = controller.start(episodeId: episodeId);

      await _pumpUntil(() => player.isPlaying);
      expect(player.currentFilePath, contains('tts_playback_0'));

      player.simulateCompletion();
      await _pumpUntil(
          () => player.currentFilePath?.contains('tts_playback_1') ?? false);

      player.simulateCompletion();
      await _pumpUntil(
          () => player.currentFilePath?.contains('tts_playback_2') ?? false);

      player.simulateCompletion();
      await future;

      expect(player.playedFiles, hasLength(3));
      expect(container.read(ttsPlaybackStateProvider),
          TtsPlaybackState.stopped);
    });

    test('updates highlight range for each segment', () async {
      final episodeId = await createTestEpisode(segmentCount: 2);
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
        bufferDrainDelay: Duration.zero,
      );

      final future = controller.start(episodeId: episodeId);

      await _pumpUntil(() => player.isPlaying);
      final highlight1 = container.read(ttsHighlightRangeProvider);
      expect(highlight1, isNotNull);
      expect(highlight1!.start, 0);
      expect(highlight1.end, 5);

      player.simulateCompletion();
      await _pumpUntil(() {
        final h = container.read(ttsHighlightRangeProvider);
        return h != null && h.start == 6;
      });

      final highlight2 = container.read(ttsHighlightRangeProvider);
      expect(highlight2, isNotNull);
      expect(highlight2!.start, 6);
      expect(highlight2.end, 11);

      player.simulateCompletion();
      await future;
    });

    test('stop resets state and clears highlight', () async {
      final episodeId = await createTestEpisode();
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
        bufferDrainDelay: Duration.zero,
      );

      final future = controller.start(episodeId: episodeId);
      await _pumpUntil(() => player.isPlaying);

      await controller.stop();
      await future;

      expect(container.read(ttsPlaybackStateProvider),
          TtsPlaybackState.stopped);
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
        bufferDrainDelay: Duration.zero,
      );

      final future =
          controller.start(episodeId: episodeId, startOffset: 6);
      await _pumpUntil(() => player.isPlaying);

      // Should be playing segment 1, not segment 0
      final highlight = container.read(ttsHighlightRangeProvider);
      expect(highlight, isNotNull);
      expect(highlight!.start, 6);

      await controller.stop();
      await future;
    });

    test('starts from segment 0 when no offset specified', () async {
      final episodeId = await createTestEpisode();
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
        bufferDrainDelay: Duration.zero,
      );

      final future = controller.start(episodeId: episodeId);
      await _pumpUntil(() => player.isPlaying);

      final highlight = container.read(ttsHighlightRangeProvider);
      expect(highlight, isNotNull);
      expect(highlight!.start, 0);

      await controller.stop();
      await future;
    });

    test('cleans up temporary files on stop', () async {
      final episodeId = await createTestEpisode();
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
        bufferDrainDelay: Duration.zero,
      );

      final future = controller.start(episodeId: episodeId);
      await _pumpUntil(() => player.isPlaying);

      final filesBefore = Directory(tempDir.path)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('tts_playback_'))
          .toList();
      expect(filesBefore, isNotEmpty);

      await controller.stop();
      await future;

      final filesAfter = Directory(tempDir.path)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('tts_playback_'))
          .toList();
      expect(filesAfter, isEmpty);
    });

    test('Duration.zero buffer drain on last segment skips wait', () async {
      final episodeId = await createTestEpisode(segmentCount: 1);
      final player = FakeAudioPlayer();
      final controller = TtsStoredPlayerController(
        ref: container,
        audioPlayer: player,
        repository: repository,
        tempDirPath: tempDir.path,
        bufferDrainDelay: Duration.zero,
      );

      final stopwatch = Stopwatch()..start();
      final future = controller.start(episodeId: episodeId);
      await _pumpUntil(() => player.isPlaying);
      player.simulateCompletion();
      await future;
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'Duration.zero must short-circuit drain');
    });
  });
}
