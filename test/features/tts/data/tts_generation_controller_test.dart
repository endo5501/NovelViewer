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
  void synthesize(String text, {String? refWavPath}) {
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

      // Episode should be deleted
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode, isNull);

      expect(cancelIsolate.disposed, isTrue);
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

      // Episode should be cleaned up
      final episode =
          await repository.findEpisodeByFileName('0001_テスト.txt');
      expect(episode, isNull);

      expect(reportedError, contains('Engine crash'));
      expect(isolate.disposed, isTrue);
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
  void synthesize(String text, {String? refWavPath}) {
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
  void synthesize(String text, {String? refWavPath}) {
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
