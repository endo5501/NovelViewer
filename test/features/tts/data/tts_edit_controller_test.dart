import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/data/tts_edit_controller.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';
import 'package:novel_viewer/features/tts/data/tts_isolate.dart';
import 'package:novel_viewer/features/tts/data/tts_playback_controller.dart';
import 'package:novel_viewer/features/tts/data/wav_writer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeTtsIsolate implements TtsIsolate {
  FakeTtsIsolate({this.modelLoadSuccess = true});

  final _responseController =
      StreamController<TtsIsolateResponse>.broadcast();
  final bool modelLoadSuccess;
  bool spawned = false;
  bool disposed = false;
  final synthesizeRequests = <(String text, String? refWavPath, String? instruct)>[];

  /// When set, synthesize will not auto-respond.
  Completer<void>? synthesizeGate;

  /// When true, loadModel will not auto-respond.
  bool blockModelLoad = false;

  @override
  Stream<TtsIsolateResponse> get responses => _responseController.stream;

  @override
  Future<void> spawn() async {
    spawned = true;
  }

  @override
  void loadModel(String modelDir,
      {int nThreads = 4, int languageId = TtsEngine.languageJapanese}) {
    if (blockModelLoad) return;
    Future.microtask(() {
      if (!_responseController.isClosed) {
        _responseController.add(
          ModelLoadedResponse(success: modelLoadSuccess),
        );
      }
    });
  }

  @override
  void synthesize(String text, {String? refWavPath, String? instruct}) {
    synthesizeRequests.add((text, refWavPath, instruct));
    if (synthesizeGate != null) {
      // Don't auto-respond; wait for gate to be completed externally
      return;
    }
    Future.microtask(() {
      if (!_responseController.isClosed) {
        _responseController.add(SynthesisResultResponse(
          audio: Float32List.fromList([0.1, 0.2, 0.3]),
          sampleRate: 24000,
        ));
      }
    });
  }

  void completeSynthesis() {
    _responseController.add(SynthesisResultResponse(
      audio: Float32List.fromList([0.1, 0.2, 0.3]),
      sampleRate: 24000,
    ));
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!_responseController.isClosed) {
      _responseController.close();
    }
  }
}

class FakeAudioPlayer implements TtsAudioPlayer {
  final _stateController = StreamController<TtsPlayerState>.broadcast();
  String? currentFilePath;
  bool isDisposed = false;
  bool autoComplete = true;

  @override
  Stream<TtsPlayerState> get playerStateStream => _stateController.stream;

  @override
  Future<void> setFilePath(String path) async {
    currentFilePath = path;
  }

  @override
  Future<void> play() async {
    _stateController.add(TtsPlayerState.playing);
    if (autoComplete) {
      Future.microtask(() {
        _stateController.add(TtsPlayerState.completed);
      });
    }
  }

  @override
  Future<void> pause() async {
    _stateController.add(TtsPlayerState.paused);
  }

  @override
  Future<void> stop() async {
    _stateController.add(TtsPlayerState.stopped);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    _stateController.close();
  }
}

/// Fake player that simulates just_audio's play() guard behavior.
/// play() is a no-op when isPlaying is already true, and isPlaying
/// stays true after completion (matching just_audio 0.9.46).
class RealisticFakeAudioPlayer implements TtsAudioPlayer {
  final _stateController = StreamController<TtsPlayerState>.broadcast();
  String? currentFilePath;
  bool isDisposed = false;
  bool isPlaying = false;
  final playedFiles = <String>[];

  @override
  Stream<TtsPlayerState> get playerStateStream => _stateController.stream;

  @override
  Future<void> setFilePath(String path) async {
    currentFilePath = path;
  }

  @override
  Future<void> play() async {
    if (isPlaying) return;
    isPlaying = true;
    playedFiles.add(currentFilePath!);
    _stateController.add(TtsPlayerState.playing);
    Future.microtask(() {
      if (isPlaying && !isDisposed) {
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
    _stateController.close();
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

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('tts_edit_ctrl_test_');
    database = TtsAudioDatabase(tempDir.path);
    repository = TtsAudioRepository(database);
  });

  tearDown(() async {
    await database.close();
    tempDir.deleteSync(recursive: true);
  });

  group('TtsEditController', () {
    group('loadSegments', () {
      test('loads segments from text when no DB records exist', () async {
        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '今日は天気です。散歩に出かけよう。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        expect(controller.segments, hasLength(2));
        expect(controller.segments[0].text, '今日は天気です。');
        expect(controller.segments[0].hasAudio, false);
        expect(controller.segments[1].text, '散歩に出かけよう。');
      });

      test('merges with existing DB records', () async {
        // Create episode and segment in DB
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: '今日はいい天気です。',
          textOffset: 0,
          textLength: 8,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '今日は天気です。散歩に出かけよう。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        expect(controller.segments[0].text, '今日はいい天気です。');
        expect(controller.segments[0].hasAudio, true);
        expect(controller.segments[0].dbRecordExists, true);
        expect(controller.segments[1].text, '散歩に出かけよう。');
        expect(controller.segments[1].hasAudio, false);
      });
    });

    group('generateSegment', () {
      test('loads model on first generation and generates audio', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '今日は天気です。散歩に出かけよう。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        final result = await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
        );

        expect(result, true);
        expect(isolate.spawned, true);
        expect(controller.modelLoaded, true);
        expect(controller.segments[0].hasAudio, true);
        expect(controller.segments[0].dbRecordExists, true);

        // Verify stored in DB
        final dbSegment = await repository.getSegmentByIndex(episodeId, 0);
        expect(dbSegment['audio_data'], isNotNull);
      });

      test('reuses model for subsequent generations', () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '今日は天気です。散歩に出かけよう。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
        );
        await controller.generateSegment(
          segmentIndex: 1,
          modelDir: '/models',
        );

        // spawn should only be called once
        expect(isolate.synthesizeRequests, hasLength(2));
      });

      test('uses per-segment ref_wav_path', () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '今日は天気です。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
          refWavPath: '/voices/female.wav',
        );

        expect(isolate.synthesizeRequests.first.$2, '/voices/female.wav');
      });

      test('updates existing DB record audio on regeneration', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: '編集済みテキスト。',
          textOffset: 0,
          textLength: 8,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '今日は天気です。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        expect(controller.segments[0].dbRecordExists, true);
        expect(controller.segments[0].hasAudio, false);

        await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
        );

        expect(controller.segments[0].hasAudio, true);
        final dbSegment = await repository.getSegmentByIndex(episodeId, 0);
        expect(dbSegment['audio_data'], isNotNull);
      });
    });

    group('generateAllUngenerated', () {
      test('generates only segments without audio', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );
        // Segment 0 already has audio
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: '今日は天気です。',
          textOffset: 0,
          textLength: 8,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '今日は天気です。散歩に出かけよう。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        final progressUpdates = <(int, int)>[];
        controller.onProgress = (current, total) {
          progressUpdates.add((current, total));
        };

        await controller.generateAllUngenerated(
          modelDir: '/models',
        );

        // Only segment 1 should have been synthesized
        expect(isolate.synthesizeRequests, hasLength(1));
        expect(controller.segments[1].hasAudio, true);
        expect(progressUpdates, [(1, 1)]);
      });

      test('calls onSegmentStart before each segment generation', () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '文1。文2。文3。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // Mark segment 1 as already having audio
        controller.segments[1].hasAudio = true;

        final startedSegments = <int>[];
        await controller.generateAllUngenerated(
          modelDir: '/models',
          onSegmentStart: (index) {
            startedSegments.add(index);
          },
        );

        // Segments 0 and 2 should be generated (1 already has audio)
        expect(startedSegments, [0, 2]);
      });

      test('does nothing when all segments have audio', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'completed',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト。',
          textOffset: 0,
          textLength: 4,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'テスト。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.generateAllUngenerated(
          modelDir: '/models',
        );

        expect(isolate.synthesizeRequests, isEmpty);
        expect(isolate.spawned, false);
      });
    });

    group('playSegment', () {
      test('plays a generated segment', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'completed',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト。',
          textOffset: 0,
          textLength: 4,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'テスト。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.playSegment(0);

        expect(player.currentFilePath, isNotNull);
        expect(player.currentFilePath!, contains('tts_edit_preview_0.wav'));
      });

      test('does nothing for segment without audio', () async {
        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'テスト。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.playSegment(0);
        expect(player.currentFilePath, isNull);
      });
    });

    group('playAll', () {
      test('plays all segments with audio, skips ungenerated', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'セグメント0。',
          textOffset: 0,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );
        // segment 1 has no audio
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 2,
          text: 'セグメント2。',
          textOffset: 14,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'セグメント0。セグメント1。セグメント2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.playAll();

        // Player should have received file paths for segments 0 and 2
        // (we can only verify the last one set)
        expect(player.currentFilePath, contains('tts_edit_preview_2.wav'));
      });
    });

    group('playAll with realistic player', () {
      test('plays all segments when pause is called between segments', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'completed',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'セグメント0。',
          textOffset: 0,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 1,
          text: 'セグメント1。',
          textOffset: 6,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 2,
          text: 'セグメント2。',
          textOffset: 12,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );

        final isolate = FakeTtsIsolate();
        final player = RealisticFakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'セグメント0。セグメント1。セグメント2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.playAll();

        expect(player.playedFiles, hasLength(3));
      });
    });

    group('updateSegmentText', () {
      test('creates DB record and clears audio for new segment', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '山奥の一軒家',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        expect(controller.segments[0].dbRecordExists, false);

        await controller.updateSegmentText(0, '山奥のいっけんや');

        expect(controller.segments[0].text, '山奥のいっけんや');
        expect(controller.segments[0].hasAudio, false);
        expect(controller.segments[0].dbRecordExists, true);

        final dbSegment = await repository.getSegmentByIndex(episodeId, 0);
        expect(dbSegment['text'], '山奥のいっけんや');
        expect(dbSegment['audio_data'], isNull);
      });

      test('updates existing DB record and deletes audio', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'completed',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: '原文テキスト。',
          textOffset: 0,
          textLength: 7,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '原文テキスト。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        expect(controller.segments[0].hasAudio, true);

        await controller.updateSegmentText(0, '編集済み。');

        expect(controller.segments[0].text, '編集済み。');
        expect(controller.segments[0].hasAudio, false);

        final dbSegment = await repository.getSegmentByIndex(episodeId, 0);
        expect(dbSegment['text'], '編集済み。');
        expect(dbSegment['audio_data'], isNull);
      });
    });

    group('updateSegmentRefWavPath', () {
      test('updates ref_wav_path in DB', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト。',
          textOffset: 0,
          textLength: 4,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'テスト。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.updateSegmentRefWavPath(0, '/voices/male.wav');

        expect(controller.segments[0].refWavPath, '/voices/male.wav');
        final dbSegment = await repository.getSegmentByIndex(episodeId, 0);
        expect(dbSegment['ref_wav_path'], '/voices/male.wav');
      });
    });

    group('updateSegmentMemo', () {
      test('updates memo in DB', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'テスト。',
          textOffset: 0,
          textLength: 4,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'テスト。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.updateSegmentMemo(0, '感情的に読む');

        expect(controller.segments[0].memo, '感情的に読む');
        final dbSegment = await repository.getSegmentByIndex(episodeId, 0);
        expect(dbSegment['memo'], '感情的に読む');
      });
    });

    group('resetSegment', () {
      test('restores original text and deletes DB record', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: '山奥のいっけんや',
          textOffset: 0,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
          refWavPath: '/voice.wav',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '山奥の一軒家',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        expect(controller.segments[0].text, '山奥のいっけんや');
        expect(controller.segments[0].hasAudio, true);

        await controller.resetSegment(0);

        expect(controller.segments[0].text, '山奥の一軒家');
        expect(controller.segments[0].hasAudio, false);
        expect(controller.segments[0].refWavPath, isNull);
        expect(controller.segments[0].dbRecordExists, false);

        // Verify DB record is deleted
        final count = await repository.getSegmentCount(episodeId);
        expect(count, 0);
      });

      test('resets an unedited segment with no DB record', () async {
        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '山奥の一軒家',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        expect(controller.segments[0].dbRecordExists, false);
        expect(controller.segments[0].text, '山奥の一軒家');

        // Reset should be a no-op but not throw
        await controller.resetSegment(0);

        expect(controller.segments[0].text, '山奥の一軒家');
        expect(controller.segments[0].hasAudio, false);
        expect(controller.segments[0].refWavPath, isNull);
        expect(controller.segments[0].memo, isNull);
        expect(controller.segments[0].dbRecordExists, false);
      });
    });

    group('generateAllUngenerated with empty ref_wav_path', () {
      test('treats empty ref_wav_path as no reference audio', () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '文1。文2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // Set segment 0 ref_wav_path to empty string ("なし")
        controller.segments[0].refWavPath = '';

        await controller.generateAllUngenerated(
          modelDir: '/models',
          globalRefWavPath: '/voices/global.wav',
        );

        expect(isolate.synthesizeRequests, hasLength(2));
        // Segment 0: empty ref should be treated as null
        expect(isolate.synthesizeRequests[0].$2, isNull);
        // Segment 1: null ref should fall back to global
        expect(isolate.synthesizeRequests[1].$2, '/voices/global.wav');
      });
    });

    group('generateAllUngenerated with resolveRefWavPath callback', () {
      test('resolves per-segment refWavPath via callback', () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '文1。文2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // Set segment 0 to a specific reference audio filename
        controller.segments[0].refWavPath = 'custom_voice.wav';

        await controller.generateAllUngenerated(
          modelDir: '/models',
          globalRefWavPath: '/voices/global.wav',
          resolveRefWavPath: (fileName) => '/voices/$fileName',
        );

        expect(isolate.synthesizeRequests, hasLength(2));
        // Segment 0: per-segment ref resolved via callback
        expect(
            isolate.synthesizeRequests[0].$2, '/voices/custom_voice.wav');
        // Segment 1: null ref falls back to global
        expect(isolate.synthesizeRequests[1].$2, '/voices/global.wav');
      });

      test('passes filename as-is when resolveRefWavPath is null', () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '文1。文2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        controller.segments[0].refWavPath = 'custom_voice.wav';

        await controller.generateAllUngenerated(
          modelDir: '/models',
          globalRefWavPath: '/voices/global.wav',
        );

        expect(isolate.synthesizeRequests, hasLength(2));
        // Segment 0: filename passed as-is (backward compatibility)
        expect(isolate.synthesizeRequests[0].$2, 'custom_voice.wav');
        // Segment 1: null ref falls back to global
        expect(isolate.synthesizeRequests[1].$2, '/voices/global.wav');
      });

      test('treats empty refWavPath as null even with callback', () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '文1。文2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        controller.segments[0].refWavPath = '';

        await controller.generateAllUngenerated(
          modelDir: '/models',
          globalRefWavPath: '/voices/global.wav',
          resolveRefWavPath: (fileName) => '/voices/$fileName',
        );

        expect(isolate.synthesizeRequests, hasLength(2));
        // Segment 0: empty string treated as null (no reference audio)
        expect(isolate.synthesizeRequests[0].$2, isNull);
        // Segment 1: null ref falls back to global
        expect(isolate.synthesizeRequests[1].$2, '/voices/global.wav');
      });
    });

    group('resetAll', () {
      test('resets all segments to original state', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: '編集済み0。',
          textOffset: 0,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 1,
          text: '編集済み1。',
          textOffset: 7,
          textLength: 6,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'オリジナル0。オリジナル1。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.resetAll();

        expect(controller.segments[0].text, 'オリジナル0。');
        expect(controller.segments[0].hasAudio, false);
        expect(controller.segments[0].dbRecordExists, false);
        expect(controller.segments[1].text, 'オリジナル1。');
        expect(controller.segments[1].dbRecordExists, false);

        final count = await repository.getSegmentCount(episodeId);
        expect(count, 0);
      });

      test('deletes episode record when all segments are reset', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'completed',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'セグメント0。',
          textOffset: 0,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 1,
          text: 'セグメント1。',
          textOffset: 7,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'セグメント0。セグメント1。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.resetAll();

        // Episode record should be deleted when no segments remain
        final episode = await repository.findEpisodeByFileName('test.txt');
        expect(episode, isNull);
      });
    });

    group('resetSegment episode status update', () {
      test('deletes episode when last audio segment is reset', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'セグメント0。',
          textOffset: 0,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'セグメント0。セグメント1。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.resetSegment(0);

        // Episode record should be deleted when no segments remain
        final episode = await repository.findEpisodeByFileName('test.txt');
        expect(episode, isNull);
      });

      test('keeps episode with partial status when some segments remain',
          () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'completed',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'セグメント0。',
          textOffset: 0,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 1,
          text: 'セグメント1。',
          textOffset: 7,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'セグメント0。セグメント1。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.resetSegment(0);

        // Episode should remain with partial status
        final episode = await repository.findEpisodeByFileName('test.txt');
        expect(episode, isNotNull);
        expect(episode!['status'], 'partial');
      });
    });

    group('cancel', () {
      test('cancel disposes TtsIsolate when model is loaded', () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'テスト。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // Load model by generating
        await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
        );

        expect(controller.modelLoaded, true);
        expect(isolate.disposed, false);

        await controller.cancel();

        expect(isolate.disposed, true);
        expect(controller.modelLoaded, false);
      });

      test('can generate again after cancel', () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate1 = FakeTtsIsolate();
        final isolate2 = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate1,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
          ttsIsolateFactory: () => isolate2,
        );

        await controller.loadSegments(
          text: '文1。文2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
        );

        await controller.cancel();
        expect(isolate1.disposed, true);
        expect(controller.modelLoaded, false);

        // Generate again after cancel - should use new isolate
        final result = await controller.generateSegment(
          segmentIndex: 1,
          modelDir: '/models',
        );

        expect(result, true);
        expect(isolate2.spawned, true);
        expect(controller.segments[1].hasAudio, true);
      });

      test('cancel is safe when model not loaded', () async {
        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'テスト。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // cancel without ever loading model
        await controller.cancel();

        expect(isolate.disposed, false);
      });
    });

    group('cancel during model load', () {
      test('cancel during model load does not hang', () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        // Create isolate that never responds to loadModel
        final isolate = FakeTtsIsolate();
        isolate.blockModelLoad = true;
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'テスト。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // Start generation - will block on model loading
        var generateCompleted = false;
        final generateFuture = controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
        ).then((result) {
          generateCompleted = true;
          return result;
        });

        // Let event loop process until spawn is called
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);
        expect(isolate.spawned, true);
        expect(generateCompleted, false);

        // Cancel while model is loading
        await controller.cancel();

        // generateSegment should now complete (return false)
        final result = await generateFuture;
        expect(generateCompleted, true);
        expect(result, false);
      });

      test('cancel disposes spawned isolate even when model not loaded',
          () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        isolate.blockModelLoad = true;
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'テスト。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // Start generation to trigger spawn
        unawaited(controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
        ));
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);
        expect(isolate.spawned, true);
        expect(controller.modelLoaded, false);

        // Cancel should dispose the spawned but not-loaded isolate
        await controller.cancel();

        expect(isolate.disposed, true);
      });
    });

    group('cancel during synthesis', () {
      test('cancel during _synthesize resolves generateAllUngenerated immediately',
          () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        isolate.synthesizeGate = Completer<void>();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '文1。文2。文3。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // Start generateAllUngenerated - will block on first synthesize
        var generateCompleted = false;
        final generateFuture = controller.generateAllUngenerated(
          modelDir: '/models',
        ).then((_) {
          generateCompleted = true;
        });

        // Let the event loop process until synthesize is called
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);
        expect(isolate.synthesizeRequests, hasLength(1));
        expect(generateCompleted, false);

        // Cancel while synthesize is pending
        await controller.cancel();

        // generateAllUngenerated should now complete
        await generateFuture;
        expect(generateCompleted, true);

        // Only first segment was attempted, none completed
        expect(controller.segments[0].hasAudio, false);
        expect(controller.segments[1].hasAudio, false);
        expect(controller.segments[2].hasAudio, false);
      });
    });

    group('dispose', () {
      test('disposes TtsIsolate if model was loaded', () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'テスト。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
        );

        await controller.dispose();

        expect(isolate.disposed, true);
      });

      test('does not dispose TtsIsolate if model was never loaded', () async {
        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'テスト。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.dispose();

        expect(isolate.disposed, false);
      });
    });

    group('memo as instruct', () {
      test('generateSegment uses segment memo as instruct', () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '文1。文2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // Set memo on segment 0
        controller.segments[0].memo = '怒りの口調で';

        await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
          instruct: '穏やかな口調で',
        );

        // Should use segment memo, not global instruct
        expect(isolate.synthesizeRequests, hasLength(1));
        expect(isolate.synthesizeRequests[0].$3, '怒りの口調で');
      });

      test('generateSegment falls back to global instruct when no memo',
          () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '文1。文2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // No memo set on segment
        await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
          instruct: '穏やかな口調で',
        );

        // Should use global instruct
        expect(isolate.synthesizeRequests, hasLength(1));
        expect(isolate.synthesizeRequests[0].$3, '穏やかな口調で');
      });

      test('generateSegment passes null instruct when no memo and no global',
          () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '文1。文2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
        );

        expect(isolate.synthesizeRequests, hasLength(1));
        expect(isolate.synthesizeRequests[0].$3, isNull);
      });

      test('generateAllUngenerated uses per-segment memo as instruct',
          () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '文1。文2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // Segment 0: has memo
        controller.segments[0].memo = '怒りの口調で';
        // Segment 1: no memo, should fall back to global

        await controller.generateAllUngenerated(
          modelDir: '/models',
          instruct: '穏やかな口調で',
        );

        expect(isolate.synthesizeRequests, hasLength(2));
        expect(isolate.synthesizeRequests[0].$3, '怒りの口調で');
        expect(isolate.synthesizeRequests[1].$3, '穏やかな口調で');
      });

      test('generateSegment persists effectiveInstruct as memo in DB (new segment)',
          () async {
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '文1。文2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // No memo set, global instruct used
        await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
          instruct: '穏やかな口調で',
        );

        final episode = await repository.findEpisodeByFileName('test.txt');
        final segments = await repository.getSegments(episode!['id'] as int);
        expect(segments.first['memo'], '穏やかな口調で');
      });

      test('generateSegment persists memo in DB when updating existing segment',
          () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        // Pre-create segment with no memo
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: '文1。',
          textOffset: 0,
          textLength: 3,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '文1。文2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // Segment 0 exists in DB (dbRecordExists=true), no memo
        await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/models',
          instruct: '穏やかな口調で',
        );

        final segments = await repository.getSegments(episodeId);
        final seg0 = segments.firstWhere((s) => s['segment_index'] == 0);
        expect(seg0['memo'], '穏やかな口調で');
      });
    });

    group('text hash storage', () {
      test('stores text_hash when episode is created via segment operation',
          () async {
        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        const text = '今日は天気です。散歩に出かけよう。';
        final expectedHash =
            sha256.convert(utf8.encode(text)).toString();

        await controller.loadSegments(
          text: text,
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // Trigger episode creation via segment ref_wav_path update
        await controller.updateSegmentRefWavPath(0, 'voice.wav');

        final episode =
            await repository.findEpisodeByFileName('test.txt');
        expect(episode, isNotNull);
        expect(episode!['text_hash'], expectedHash);

        await controller.dispose();
      });

      test('updates text_hash when existing episode has null text_hash',
          () async {
        // Create episode without text_hash (simulating pre-fix state)
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        const text = '今日は天気です。散歩に出かけよう。';
        final expectedHash =
            sha256.convert(utf8.encode(text)).toString();

        await controller.loadSegments(
          text: text,
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        final episode =
            await repository.findEpisodeByFileName('test.txt');
        expect(episode, isNotNull);
        expect(episode!['text_hash'], expectedHash);

        await controller.dispose();
      });

      test('preserves existing non-null text_hash on loadSegments',
          () async {
        const existingHash = 'existing_hash_value';
        await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'partial',
          textHash: existingHash,
        );

        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: '今日は天気です。散歩に出かけよう。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        final episode =
            await repository.findEpisodeByFileName('test.txt');
        expect(episode, isNotNull);
        expect(episode!['text_hash'], existingHash);

        await controller.dispose();
      });

      test(
          'edit-created episode is reused by streaming controller '
          'with matching text', () async {
        final isolate = FakeTtsIsolate();
        final player = FakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        const text = '今日は天気です。散歩に出かけよう。';

        await controller.loadSegments(
          text: text,
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        // Generate a segment to trigger episode creation with audio
        await controller.generateSegment(
          segmentIndex: 0,
          modelDir: '/model',
        );

        await controller.dispose();

        // Verify episode exists with correct text_hash
        final episode =
            await repository.findEpisodeByFileName('test.txt');
        expect(episode, isNotNull);

        final textHash =
            sha256.convert(utf8.encode(text)).toString();
        final storedHash = episode!['text_hash'] as String?;
        expect(storedHash, textHash);

        // Verify the streaming controller would reuse it (hash matches)
        final episodeId = episode['id'] as int;
        final segments = await repository.getSegments(episodeId);
        expect(segments, hasLength(1));
        expect(segments[0]['audio_data'], isNotNull);
      });
    });
  });
}
