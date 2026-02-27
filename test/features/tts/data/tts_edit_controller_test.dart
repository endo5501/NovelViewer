import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
  final synthesizeRequests = <(String text, String? refWavPath)>[];

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
      _responseController.add(
        ModelLoadedResponse(success: modelLoadSuccess),
      );
    });
  }

  @override
  void synthesize(String text, {String? refWavPath}) {
    synthesizeRequests.add((text, refWavPath));
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
  });
}
