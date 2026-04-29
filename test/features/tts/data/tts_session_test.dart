import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/data/tts_isolate.dart';
import 'package:novel_viewer/features/tts/data/tts_language.dart';
import 'package:novel_viewer/features/tts/data/tts_session.dart';
import 'package:novel_viewer/features/tts/domain/tts_engine_config.dart';

class _LoadModelCall {
  _LoadModelCall({
    required this.modelDir,
    required this.engineType,
    required this.languageId,
    this.dicDir,
    this.lengthScale,
    this.noiseScale,
    this.noiseW,
    this.embeddingCacheDir,
  });
  final String modelDir;
  final TtsEngineType engineType;
  final int languageId;
  final String? dicDir;
  final double? lengthScale;
  final double? noiseScale;
  final double? noiseW;
  final String? embeddingCacheDir;
}

class _FakeTtsIsolate implements TtsIsolate {
  final _responseController =
      StreamController<TtsIsolateResponse>.broadcast();
  bool spawned = false;
  bool disposed = false;
  bool aborted = false;
  final loadModelCalls = <_LoadModelCall>[];
  final synthesizeRequests = <(String text, String? refWavPath)>[];
  Completer<void>? synthesizeGate;
  bool blockModelLoad = false;
  bool autoSucceedSynthesis = true;

  @override
  Stream<TtsIsolateResponse> get responses => _responseController.stream;

  @override
  Future<void> spawn() async {
    spawned = true;
  }

  @override
  void loadModel(
    String modelDir, {
    TtsEngineType engineType = TtsEngineType.qwen3,
    int nThreads = 4,
    int languageId = TtsLanguage.defaultLanguageId,
    String? dicDir,
    double? lengthScale,
    double? noiseScale,
    double? noiseW,
    String? embeddingCacheDir,
  }) {
    loadModelCalls.add(_LoadModelCall(
      modelDir: modelDir,
      engineType: engineType,
      languageId: languageId,
      dicDir: dicDir,
      lengthScale: lengthScale,
      noiseScale: noiseScale,
      noiseW: noiseW,
      embeddingCacheDir: embeddingCacheDir,
    ));
    if (blockModelLoad) return;
    Future.microtask(() {
      if (!_responseController.isClosed) {
        _responseController.add(ModelLoadedResponse(success: true));
      }
    });
  }

  @override
  void synthesize(String text, {String? refWavPath}) {
    synthesizeRequests.add((text, refWavPath));
    if (synthesizeGate != null) return;
    if (!autoSucceedSynthesis) return;
    Future.microtask(() {
      if (!_responseController.isClosed) {
        _responseController.add(SynthesisResultResponse(
          audio: Float32List.fromList([0.1, 0.2]),
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

  @override
  void abort() {
    aborted = true;
  }

  void completeSynthesis({String? error}) {
    _responseController.add(SynthesisResultResponse(
      audio: error == null ? Float32List.fromList([0.1, 0.2]) : null,
      sampleRate: 24000,
      error: error,
    ));
  }

  void emitModelLoaded({bool success = true, String? error}) {
    _responseController.add(
      ModelLoadedResponse(success: success, error: error),
    );
  }
}

void main() {
  group('TtsSession', () {
    test('ensureModelLoaded sends loadModel for qwen3 config', () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(isolate: isolate);

      await session.ensureModelLoaded(_qwen3());

      expect(isolate.spawned, isTrue);
      expect(isolate.loadModelCalls, hasLength(1));
      final call = isolate.loadModelCalls.first;
      expect(call.engineType, TtsEngineType.qwen3);
      expect(call.modelDir, '/q/m');
      expect(call.languageId, 2058);
      expect(call.embeddingCacheDir, '/cache');
      await session.dispose();
    });

    test('ensureModelLoaded sends piper params when piper config is given',
        () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(isolate: isolate);

      await session.ensureModelLoaded(_piper());

      expect(isolate.loadModelCalls, hasLength(1));
      final call = isolate.loadModelCalls.first;
      expect(call.engineType, TtsEngineType.piper);
      expect(call.modelDir, '/p/m.onnx');
      expect(call.dicDir, '/p/dic');
      expect(call.lengthScale, 0.9);
      expect(call.noiseScale, 0.5);
      expect(call.noiseW, 0.7);
      await session.dispose();
    });

    test('second ensureModelLoaded with same config is a no-op', () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(isolate: isolate);

      final config = _qwen3();
      await session.ensureModelLoaded(config);
      await session.ensureModelLoaded(config);

      expect(isolate.loadModelCalls, hasLength(1));
      await session.dispose();
    });

    test('two distinct-but-equivalent Qwen3 configs reuse the loaded model',
        () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(isolate: isolate);

      // Same modelDir/languageId — only refWavPath (synthesis-time) differs.
      const a = Qwen3EngineConfig(
        modelDir: '/q/m',
        sampleRate: 24000,
        languageId: 2058,
        refWavPath: '/voice/a.wav',
      );
      const b = Qwen3EngineConfig(
        modelDir: '/q/m',
        sampleRate: 24000,
        languageId: 2058,
        refWavPath: '/voice/b.wav',
      );

      await session.ensureModelLoaded(a);
      await session.ensureModelLoaded(b);

      expect(isolate.loadModelCalls, hasLength(1),
          reason:
              'changing only synthesis-time fields must not trigger reload');
      await session.dispose();
    });

    test('synthesize resolves with audio result on happy path', () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(isolate: isolate);
      await session.ensureModelLoaded(_qwen3());

      final result = await session.synthesize(text: 'こんにちは');
      expect(result, isNotNull);
      expect(result!.audio, isNotNull);
      expect(isolate.synthesizeRequests.first.$1, 'こんにちは');
      await session.dispose();
    });

    test('abort completes in-flight synthesize with null and aborts isolate',
        () async {
      final isolate = _FakeTtsIsolate();
      isolate.synthesizeGate = Completer<void>();
      final session = TtsSession(isolate: isolate);
      await session.ensureModelLoaded(_qwen3());

      final synthesisFuture = session.synthesize(text: 'pending');
      // Let event loop process so synthesize is sent
      await Future.delayed(Duration.zero);
      expect(isolate.synthesizeRequests, hasLength(1));

      session.abort();
      final result = await synthesisFuture;

      expect(result, isNull);
      expect(isolate.aborted, isTrue);
      await session.dispose();
    });

    test('dispose tears down subscription and isolate', () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(isolate: isolate);
      await session.ensureModelLoaded(_qwen3());
      await session.dispose();

      expect(isolate.disposed, isTrue);
    });

    test('ensureModelLoaded after dispose throws StateError', () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(isolate: isolate);
      await session.dispose();

      expect(
        () => session.ensureModelLoaded(_qwen3()),
        throwsStateError,
      );
    });

    test('ensureModelLoaded after abort waits and proceeds with new config',
        () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(isolate: isolate);

      // Start an in-flight load that we'll abort.
      isolate.blockModelLoad = true;
      final firstLoad = session.ensureModelLoaded(_qwen3());
      // Wait until the spawn happened.
      await Future.delayed(Duration.zero);
      expect(isolate.spawned, isTrue);

      session.abort();
      // Allow the abort path to complete the in-flight load with `false`.
      // The first load should resolve to `false`.
      isolate.emitModelLoaded(success: false);
      final firstResult = await firstLoad;
      expect(firstResult, isFalse);

      // Now a fresh ensureModelLoaded should succeed when the isolate replies.
      isolate.blockModelLoad = false;
      final secondResult = await session.ensureModelLoaded(_qwen3());
      expect(secondResult, isTrue);

      await session.dispose();
    });
  });
}

Qwen3EngineConfig _qwen3() => const Qwen3EngineConfig(
      modelDir: '/q/m',
      sampleRate: 24000,
      languageId: 2058,
      embeddingCacheDir: '/cache',
    );

PiperEngineConfig _piper() => const PiperEngineConfig(
      modelDir: '/p/m.onnx',
      sampleRate: 22050,
      dicDir: '/p/dic',
      lengthScale: 0.9,
      noiseScale: 0.5,
      noiseW: 0.7,
    );
