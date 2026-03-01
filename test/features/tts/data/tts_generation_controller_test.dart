import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';
import 'package:novel_viewer/features/tts/data/tts_generation_controller.dart';
import 'package:novel_viewer/features/tts/data/tts_isolate.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

/// Fake TtsIsolate for generation controller testing.
class FakeTtsIsolate implements TtsIsolate {
  FakeTtsIsolate({this.modelLoadSuccess = true, this.synthesisError});

  final _responseController =
      StreamController<TtsIsolateResponse>.broadcast();
  final bool modelLoadSuccess;
  final String? synthesisError;
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
  void loadModel(String modelDir,
      {int nThreads = 4, int languageId = TtsEngine.languageJapanese}) {
    loadedModelDir = modelDir;
    Future.microtask(() {
      if (modelLoadSuccess) {
        _responseController.add(ModelLoadedResponse(success: true));
      } else {
        _responseController
            .add(ModelLoadedResponse(success: false, error: 'Model not found'));
      }
    });
  }

  @override
  void synthesize(String text, {String? refWavPath, String? instruct}) {
    synthesizeRequests.add(text);
    Future.microtask(() {
      if (synthesisError != null) {
        _responseController.add(SynthesisResultResponse(
          audio: null,
          sampleRate: 0,
          error: synthesisError,
        ));
      } else {
        _responseController.add(SynthesisResultResponse(
          audio: Float32List.fromList([0.1, 0.2, 0.3]),
          sampleRate: 24000,
        ));
      }
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

void main() {
  late Directory tempDir;
  late TtsAudioDatabase database;
  late TtsAudioRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('tts_gen_ctrl_test_');
    database = TtsAudioDatabase(tempDir.path);
    repository = TtsAudioRepository(database);
  });

  tearDown(() async {
    await database.close();
    tempDir.deleteSync(recursive: true);
  });

  group('TtsGenerationController', () {
    test('generates all segments and saves to database', () async {
      final isolate = FakeTtsIsolate();
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      await controller.start(
        text: '今日は天気です。明日も晴れるでしょう。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // Verify isolate was used
      expect(isolate.spawned, isTrue);
      expect(isolate.loadedModelDir, '/models');
      expect(isolate.synthesizeRequests, hasLength(2));
      expect(isolate.synthesizeRequests[0], '今日は天気です。');
      expect(isolate.synthesizeRequests[1], '明日も晴れるでしょう。');

      // Verify DB state
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode, isNotNull);
      expect(episode!['status'], 'completed');
      expect(episode['sample_rate'], 24000);

      final segments = await repository.getSegments(episode['id'] as int);
      expect(segments, hasLength(2));
      expect(segments[0]['text'], '今日は天気です。');
      expect(segments[0]['text_offset'], 0);
      expect(segments[0]['text_length'], 8);
      expect(segments[1]['text'], '明日も晴れるでしょう。');
      expect(segments[1]['text_offset'], 8);
      expect(segments[1]['text_length'], 11);

      // Verify isolate disposed
      expect(isolate.disposed, isTrue);
    });

    test('reports progress during generation', () async {
      final isolate = FakeTtsIsolate();
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      final progressUpdates = <(int, int)>[];
      controller.onProgress = (current, total) {
        progressUpdates.add((current, total));
      };

      await controller.start(
        text: '文1。文2。文3。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      expect(progressUpdates, contains((1, 3)));
      expect(progressUpdates, contains((2, 3)));
      expect(progressUpdates, contains((3, 3)));
    });

    test('calls onSegmentStart before synthesis with correct offset and length',
        () async {
      final isolate = FakeTtsIsolate();
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      final segmentStartCalls = <(int, int)>[];
      controller.onSegmentStart = (textOffset, textLength) {
        segmentStartCalls.add((textOffset, textLength));
      };

      await controller.start(
        text: '今日は天気です。明日も晴れるでしょう。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // '今日は天気です。' starts at offset 0, length 8
      // '明日も晴れるでしょう。' starts at offset 8, length 11
      expect(segmentStartCalls, hasLength(2));
      expect(segmentStartCalls[0], (0, 8));
      expect(segmentStartCalls[1], (8, 11));
    });

    test('calls onSegmentStart before synthesize request', () async {
      final isolate = FakeTtsIsolate();
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      final synthCountAtSegmentStart = <int>[];
      controller.onSegmentStart = (offset, length) {
        synthCountAtSegmentStart.add(isolate.synthesizeRequests.length);
      };

      await controller.start(
        text: '文1。文2。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // At each onSegmentStart call, the synthesize request count should be
      // equal to the number of previously completed segments (0, then 1)
      expect(synthCountAtSegmentStart, [0, 1]);
    });

    test('calls onSegmentStart before onProgress for each segment', () async {
      final isolate = FakeTtsIsolate();
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      final callOrder = <String>[];
      controller.onSegmentStart = (textOffset, textLength) {
        callOrder.add('segmentStart:$textOffset');
      };
      controller.onProgress = (current, total) {
        callOrder.add('progress:$current');
      };

      await controller.start(
        text: '文1。文2。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // onSegmentStart should come before onProgress for each segment
      expect(callOrder, [
        'segmentStart:0',
        'progress:1',
        'segmentStart:3',
        'progress:2',
      ]);
    });

    test('can be cancelled during generation', () async {
      // Use an isolate that waits for explicit synthesis responses
      final synthesizeRequestedCompleter = Completer<void>();
      final cancelIsolate = _CancellableFakeTtsIsolate(
        onSynthesizeRequested: () {
          if (!synthesizeRequestedCompleter.isCompleted) {
            synthesizeRequestedCompleter.complete();
          }
        },
      );

      final controller = TtsGenerationController(
        ttsIsolate: cancelIsolate,
        repository: repository,
      );

      final future = controller.start(
        text: '文1。文2。文3。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // Wait until the first synthesize request is made
      await synthesizeRequestedCompleter.future;

      // Cancel while waiting for synthesis result
      await controller.cancel();

      await future;

      // Episode should be preserved with 'partial' status
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode, isNotNull);
      expect(episode!['status'], 'partial');

      expect(cancelIsolate.disposed, isTrue);
    });

    test('cancel preserves generated segments with partial status', () async {
      // Use an isolate that generates one segment then stalls
      int synthesizeCount = 0;
      final firstSegmentDone = Completer<void>();
      final stallIsolate = _StallingFakeTtsIsolate(
        onSynthesizeRequested: (text) {
          synthesizeCount++;
          if (synthesizeCount == 1) {
            // Complete first synthesis
            return true;
          }
          // Stall on second synthesis
          if (!firstSegmentDone.isCompleted) {
            firstSegmentDone.complete();
          }
          return false;
        },
      );

      final controller = TtsGenerationController(
        ttsIsolate: stallIsolate,
        repository: repository,
      );

      final future = controller.start(
        text: '文1。文2。文3。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      await firstSegmentDone.future;
      await controller.cancel();
      await future;

      // Episode should exist with 'partial' status
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode, isNotNull);
      expect(episode!['status'], 'partial');

      // First segment should be preserved
      final segments = await repository.getSegments(episode['id'] as int);
      expect(segments, hasLength(1));
      expect(segments[0]['text'], '文1。');
    });

    test('deletes existing data before regeneration', () async {
      // Pre-populate database
      final oldEpisodeId = await repository.createEpisode(
        fileName: '0001_テスト.txt',
        sampleRate: 24000,
        status: 'completed',
      );
      await repository.insertSegment(
        episodeId: oldEpisodeId,
        segmentIndex: 0,
        text: '古いテキスト。',
        textOffset: 0,
        textLength: 7,
        audioData: Uint8List(10),
        sampleCount: 100,
      );

      final isolate = FakeTtsIsolate();
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      await controller.start(
        text: '新しいテキスト。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // Old data should be gone, new data should exist
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode, isNotNull);
      expect(episode!['status'], 'completed');

      final segments = await repository.getSegments(episode['id'] as int);
      expect(segments, hasLength(1));
      expect(segments[0]['text'], '新しいテキスト。');
    });

    test('cleans up on synthesis error', () async {
      final isolate = FakeTtsIsolate(synthesisError: 'Engine crash');
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      String? reportedError;
      controller.onError = (error) {
        reportedError = error;
      };

      await controller.start(
        text: '文1。文2。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      // Episode should be preserved with 'partial' status
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode, isNotNull);
      expect(episode!['status'], 'partial');

      expect(reportedError, contains('Engine crash'));
      expect(isolate.disposed, isTrue);
    });

    test('calls onSegmentStored after each segment is saved', () async {
      final isolate = FakeTtsIsolate();
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      final storedIndices = <int>[];
      controller.onSegmentStored = (segmentIndex) {
        storedIndices.add(segmentIndex);
      };

      await controller.start(
        text: '文1。文2。文3。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      expect(storedIndices, [0, 1, 2]);
    });

    test('starts generation from specified segment index', () async {
      final isolate = FakeTtsIsolate();
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      // Pre-create episode with 1 existing segment
      final episodeId = await repository.createEpisode(
        fileName: '0001_テスト.txt',
        sampleRate: 24000,
        status: 'partial',
      );
      await repository.insertSegment(
        episodeId: episodeId,
        segmentIndex: 0,
        text: '文1。',
        textOffset: 0,
        textLength: 3,
        audioData: Uint8List(10),
        sampleCount: 100,
      );

      await controller.start(
        text: '文1。文2。文3。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
        startSegmentIndex: 1,
        existingEpisodeId: episodeId,
      );

      // Should only synthesize segments 1 and 2 (skip 0)
      expect(isolate.synthesizeRequests, hasLength(2));
      expect(isolate.synthesizeRequests[0], '文2。');
      expect(isolate.synthesizeRequests[1], '文3。');

      // Episode should be completed
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode!['status'], 'completed');

      // All 3 segments should exist
      final segments = await repository.getSegments(episodeId);
      expect(segments, hasLength(3));
    });

    test('handles model load failure', () async {
      final isolate = FakeTtsIsolate(modelLoadSuccess: false);
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      String? reportedError;
      controller.onError = (error) {
        reportedError = error;
      };

      await controller.start(
        text: '文1。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      expect(reportedError, isNotNull);
      expect(isolate.disposed, isTrue);
    });

    test('stores instruct as memo in segments', () async {
      final isolate = FakeTtsIsolate();
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      await controller.start(
        text: '文1。文2。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
        instruct: '楽しげな口調で',
      );

      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      final segments = await repository.getSegments(episode!['id'] as int);
      expect(segments, hasLength(2));
      expect(segments[0]['memo'], '楽しげな口調で');
      expect(segments[1]['memo'], '楽しげな口調で');
    });

    test('stores null memo when no instruct provided', () async {
      final isolate = FakeTtsIsolate();
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      await controller.start(
        text: '文1。文2。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      final segments = await repository.getSegments(episode!['id'] as int);
      expect(segments, hasLength(2));
      expect(segments[0]['memo'], isNull);
      expect(segments[1]['memo'], isNull);
    });

    test('passes refWavPath to isolate when provided', () async {
      final synthesizeArgs = <(String, String?)>[];
      final isolate = _TrackingFakeTtsIsolate(synthesizeArgs);

      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      await controller.start(
        text: 'テスト文。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
        refWavPath: '/path/to/ref.wav',
      );

      expect(synthesizeArgs, hasLength(1));
      expect(synthesizeArgs[0].$2, '/path/to/ref.wav');
    });

    test('stores WAV bytes in segments audio_data', () async {
      final isolate = FakeTtsIsolate();
      final controller = TtsGenerationController(
        ttsIsolate: isolate,
        repository: repository,
      );

      await controller.start(
        text: 'テスト文。',
        fileName: '0001_テスト.txt',
        modelDir: '/models',
        sampleRate: 24000,
      );

      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      final segments = await repository.getSegments(episode!['id'] as int);
      final audioData = segments[0]['audio_data'] as Uint8List;

      // Verify it's a valid WAV file (starts with RIFF header)
      expect(audioData.length, greaterThan(44));
      expect(String.fromCharCodes(audioData.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(audioData.sublist(8, 12)), 'WAVE');
    });
  });
}

/// A fake isolate that responds to model loading but not synthesis,
/// allowing cancel testing at a deterministic point.
class _CancellableFakeTtsIsolate implements TtsIsolate {
  _CancellableFakeTtsIsolate({this.onSynthesizeRequested});

  final _responseController =
      StreamController<TtsIsolateResponse>.broadcast();
  final void Function()? onSynthesizeRequested;
  bool disposed = false;

  @override
  Stream<TtsIsolateResponse> get responses => _responseController.stream;

  @override
  Future<void> spawn() async {}

  @override
  void loadModel(String modelDir,
      {int nThreads = 4, int languageId = TtsEngine.languageJapanese}) {
    Future.microtask(() {
      _responseController.add(ModelLoadedResponse(success: true));
    });
  }

  @override
  void synthesize(String text, {String? refWavPath, String? instruct}) {
    // Notify that synthesis was requested but don't respond
    onSynthesizeRequested?.call();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!_responseController.isClosed) {
      _responseController.close();
    }
  }
}

/// A fake isolate that tracks synthesize calls with their refWavPath.
class _TrackingFakeTtsIsolate implements TtsIsolate {
  _TrackingFakeTtsIsolate(this._calls);

  final List<(String, String?)> _calls;
  final _responseController =
      StreamController<TtsIsolateResponse>.broadcast();

  @override
  Stream<TtsIsolateResponse> get responses => _responseController.stream;

  @override
  Future<void> spawn() async {}

  @override
  void loadModel(String modelDir,
      {int nThreads = 4, int languageId = TtsEngine.languageJapanese}) {
    Future.microtask(() {
      _responseController.add(ModelLoadedResponse(success: true));
    });
  }

  @override
  void synthesize(String text, {String? refWavPath, String? instruct}) {
    _calls.add((text, refWavPath));
    Future.microtask(() {
      _responseController.add(SynthesisResultResponse(
        audio: Float32List.fromList([0.1, 0.2, 0.3]),
        sampleRate: 24000,
      ));
    });
  }

  @override
  Future<void> dispose() async {
    _responseController.close();
  }
}

/// A fake isolate that completes some synthesis requests and stalls on others.
/// The callback returns true to complete, false to stall.
class _StallingFakeTtsIsolate implements TtsIsolate {
  _StallingFakeTtsIsolate({required this.onSynthesizeRequested});

  final bool Function(String text) onSynthesizeRequested;
  final _responseController =
      StreamController<TtsIsolateResponse>.broadcast();
  bool disposed = false;

  @override
  Stream<TtsIsolateResponse> get responses => _responseController.stream;

  @override
  Future<void> spawn() async {}

  @override
  void loadModel(String modelDir,
      {int nThreads = 4, int languageId = TtsEngine.languageJapanese}) {
    Future.microtask(() {
      _responseController.add(ModelLoadedResponse(success: true));
    });
  }

  @override
  void synthesize(String text, {String? refWavPath, String? instruct}) {
    final shouldComplete = onSynthesizeRequested(text);
    if (shouldComplete) {
      Future.microtask(() {
        _responseController.add(SynthesisResultResponse(
          audio: Float32List.fromList([0.1, 0.2, 0.3]),
          sampleRate: 24000,
        ));
      });
    }
    // If shouldComplete is false, don't respond (stall)
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!_responseController.isClosed) {
      _responseController.close();
    }
  }
}
