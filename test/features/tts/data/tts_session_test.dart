import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
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
  bool workerDied = false;
  bool spawnThrows = false;
  final loadModelCalls = <_LoadModelCall>[];
  final synthesizeRequests = <(String text, String? refWavPath)>[];
  final synthesizeCaptions = <String?>[];
  final synthesizeSpeakerGuidance = <double?>[];
  final synthesizeCaptionGuidance = <double?>[];
  final synthesizeSteps = <int?>[];
  Completer<void>? synthesizeGate;
  bool blockModelLoad = false;
  bool autoSucceedSynthesis = true;

  @override
  Stream<TtsIsolateResponse> get responses => _responseController.stream;

  @override
  int? debugAbortHandleAddressFor(TtsEngineType engineType) => null;

  @override
  bool get hasWorkerDied => workerDied;

  @override
  Future<void> spawn() async {
    if (spawnThrows) {
      throw StateError('worker died during spawn');
    }
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
  void synthesize(
    String text, {
    String? refWavPath,
    String? caption,
    double? speakerGuidanceScale,
    double? captionGuidanceScale,
    int? numInferenceSteps,
  }) {
    synthesizeRequests.add((text, refWavPath));
    synthesizeCaptions.add(caption);
    synthesizeSpeakerGuidance.add(speakerGuidanceScale);
    synthesizeCaptionGuidance.add(captionGuidanceScale);
    synthesizeSteps.add(numInferenceSteps);
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

  @override
  void debugCrashWorker() {
    // Not used by TtsSession tests; worker death is simulated via
    // emitWorkerDied(). Present only to satisfy the TtsIsolate interface.
    emitWorkerDied('debugCrashWorker');
  }

  void completeSynthesis({String? error}) {
    _responseController.add(SynthesisResultResponse(
      audio: error == null ? Float32List.fromList([0.1, 0.2]) : null,
      sampleRate: 24000,
      error: error,
    ));
  }

  /// A failure the native side could not describe: no audio, no error string.
  void completeSynthesisWithoutAudio() {
    _responseController.add(SynthesisResultResponse(
      audio: null,
      sampleRate: 24000,
    ));
  }

  void emitModelLoaded({bool success = true, String? error}) {
    _responseController.add(
      ModelLoadedResponse(success: success, error: error),
    );
  }

  void emitWorkerDied(String error) {
    workerDied = true;
    _responseController.add(WorkerDiedResponse(error));
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

    test('ensureModelLoaded sends loadModel for irodori config', () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(isolate: isolate);

      await session.ensureModelLoaded(_irodori());

      expect(isolate.loadModelCalls, hasLength(1));
      final call = isolate.loadModelCalls.first;
      expect(call.engineType, TtsEngineType.irodori);
      expect(call.modelDir, '/i/m');
      await session.dispose();
    });

    test('two distinct-but-equivalent Irodori configs reuse the loaded model',
        () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(isolate: isolate);

      // Same modelDir — only synthesis-time fields (refWavPath / guidance /
      // steps) differ. modelLoadKey is (type, modelDir), so no reload.
      const a = IrodoriEngineConfig(
        modelDir: '/i/m',
        sampleRate: 48000,
        refWavPath: '/voice/a.wav',
        speakerGuidanceScale: 5.0,
        captionGuidanceScale: 3.0,
        numInferenceSteps: 40,
      );
      const b = IrodoriEngineConfig(
        modelDir: '/i/m',
        sampleRate: 48000,
        refWavPath: '/voice/b.wav',
        speakerGuidanceScale: 6.0,
        captionGuidanceScale: 4.5,
        numInferenceSteps: 32,
      );

      await session.ensureModelLoaded(a);
      await session.ensureModelLoaded(b);

      expect(isolate.loadModelCalls, hasLength(1),
          reason:
              'changing only synthesis-time fields must not trigger reload');
      await session.dispose();
    });

    test('synthesize forwards caption and guidance/steps to the isolate',
        () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(isolate: isolate);
      await session.ensureModelLoaded(_irodori());

      await session.synthesize(
        text: 'こんにちは',
        refWavPath: '/voice/ref.wav',
        caption: '落ち着いた大人の女性の声',
        speakerGuidanceScale: 5.0,
        captionGuidanceScale: 3.0,
        numInferenceSteps: 40,
      );

      expect(isolate.synthesizeCaptions.single, '落ち着いた大人の女性の声');
      expect(isolate.synthesizeSpeakerGuidance.single, 5.0);
      expect(isolate.synthesizeCaptionGuidance.single, 3.0);
      expect(isolate.synthesizeSteps.single, 40);
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

    test('synthesize retains the native error for the caller', () async {
      final isolate = _FakeTtsIsolate();
      isolate.autoSucceedSynthesis = false;
      final session = TtsSession(isolate: isolate);
      await session.ensureModelLoaded(_qwen3());

      final synthesisFuture = session.synthesize(text: 'bad ref');
      await Future.delayed(Duration.zero);
      isolate.completeSynthesis(
        error: 'unsupported WAV encoding (need PCM16, PCM24, or float32)',
      );

      final result = await synthesisFuture;

      expect(result, isNull, reason: 'return contract must stay nullable');
      expect(
        session.lastSynthesisError,
        contains('unsupported WAV encoding'),
      );
      await session.dispose();
    });

    test('synthesize retains the worker death reason for the caller', () async {
      final isolate = _FakeTtsIsolate();
      isolate.autoSucceedSynthesis = false;
      final session = TtsSession(isolate: isolate);
      await session.ensureModelLoaded(_qwen3());

      final synthesisFuture = session.synthesize(text: 'pending');
      await Future.delayed(Duration.zero);
      isolate.emitWorkerDied('worker crashed: RangeError');

      final result = await synthesisFuture;

      expect(result, isNull);
      expect(session.lastSynthesisError, contains('worker crashed'));
      await session.dispose();
    });

    test('successful synthesize clears a retained error', () async {
      final isolate = _FakeTtsIsolate();
      isolate.autoSucceedSynthesis = false;
      final session = TtsSession(isolate: isolate);
      await session.ensureModelLoaded(_qwen3());

      final failing = session.synthesize(text: 'bad ref');
      await Future.delayed(Duration.zero);
      isolate.completeSynthesis(error: 'could not open audio input');
      await failing;
      expect(session.lastSynthesisError, isNotNull);

      isolate.autoSucceedSynthesis = true;
      final result = await session.synthesize(text: 'fine');

      expect(result, isNotNull, reason: 'return contract must stay unchanged');
      expect(session.lastSynthesisError, isNull);
      await session.dispose();
    });

    test('the worker-died fast path does not leak the previous reason',
        () async {
      final isolate = _FakeTtsIsolate();
      isolate.autoSucceedSynthesis = false;
      final session = TtsSession(isolate: isolate);
      await session.ensureModelLoaded(_qwen3());

      final failing = session.synthesize(text: 'bad ref');
      await Future.delayed(Duration.zero);
      isolate.completeSynthesis(error: 'unsupported WAV encoding');
      await failing;
      expect(session.lastSynthesisError, isNotNull);

      // The worker dies with no synthesize in flight, so the next call takes
      // the fail-fast path that returns before any response arrives.
      isolate.emitWorkerDied('boom');
      await Future.delayed(Duration.zero);
      final result = await session.synthesize(text: 'again');

      expect(result, isNull);
      expect(session.lastSynthesisError, isNull,
          reason: 'this failure was not explained by the previous WAV error');
      await session.dispose();
    });

    test('a failure with no error string retains no reason', () async {
      final isolate = _FakeTtsIsolate();
      isolate.autoSucceedSynthesis = false;
      final session = TtsSession(isolate: isolate);
      await session.ensureModelLoaded(_qwen3());

      final synthesisFuture = session.synthesize(text: 'silent failure');
      await Future.delayed(Duration.zero);
      isolate.completeSynthesisWithoutAudio();

      expect(await synthesisFuture, isNull);
      expect(session.lastSynthesisError, isNull);
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

    test(
        'ensureModelLoaded logs a WARNING carrying the native error string '
        'when model load fails', () async {
      final isolate = _FakeTtsIsolate();
      final logger = Logger('tts.session.test.modelload');
      final session = TtsSession(isolate: isolate, logger: logger);

      final records = <LogRecord>[];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(records.add);

      try {
        isolate.blockModelLoad = true;
        final loadFuture = session.ensureModelLoaded(_qwen3());
        await Future.delayed(Duration.zero);
        isolate.emitModelLoaded(success: false, error: 'model file not found');
        final result = await loadFuture;

        expect(result, isFalse, reason: 'return contract must stay bool');
        final warnings = records
            .where((r) =>
                r.level == Level.WARNING &&
                r.loggerName == 'tts.session.test.modelload')
            .toList();
        expect(warnings, isNotEmpty);
        expect(warnings.first.message, contains('model file not found'));
      } finally {
        await sub.cancel();
        await session.dispose();
      }
    });

    test(
        'synthesize logs a WARNING carrying the native error string and still '
        'returns null', () async {
      final isolate = _FakeTtsIsolate();
      isolate.autoSucceedSynthesis = false;
      final logger = Logger('tts.session.test.synth');
      final session = TtsSession(isolate: isolate, logger: logger);
      await session.ensureModelLoaded(_qwen3());

      final records = <LogRecord>[];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(records.add);

      try {
        final synthFuture = session.synthesize(text: 'pending');
        await Future.delayed(Duration.zero);
        isolate.completeSynthesis(error: 'vocab load failed');
        final result = await synthFuture;

        expect(result, isNull, reason: 'return contract must stay nullable');
        final warnings = records
            .where((r) =>
                r.level == Level.WARNING &&
                r.loggerName == 'tts.session.test.synth')
            .toList();
        expect(warnings, isNotEmpty);
        expect(warnings.first.message, contains('vocab load failed'));
      } finally {
        await sub.cancel();
        await session.dispose();
      }
    });

    test('successful model load and synthesis emit no error WARNING', () async {
      final isolate = _FakeTtsIsolate();
      final logger = Logger('tts.session.test.happy');
      final session = TtsSession(isolate: isolate, logger: logger);

      final records = <LogRecord>[];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(records.add);

      try {
        await session.ensureModelLoaded(_qwen3());
        final result = await session.synthesize(text: 'こんにちは');
        expect(result, isNotNull);

        final warnings = records
            .where((r) =>
                r.level == Level.WARNING &&
                r.loggerName == 'tts.session.test.happy')
            .toList();
        expect(warnings, isEmpty);
      } finally {
        await sub.cancel();
        await session.dispose();
      }
    });

    test(
        'synthesize resolves with null and logs WARNING when worker dies '
        'mid-flight (F144)', () async {
      final isolate = _FakeTtsIsolate();
      isolate.autoSucceedSynthesis = false; // never replies on its own
      final logger = Logger('tts.session.test.death.synth');
      final session = TtsSession(isolate: isolate, logger: logger);
      await session.ensureModelLoaded(_qwen3());

      final records = <LogRecord>[];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(records.add);

      try {
        final synthFuture = session.synthesize(text: 'pending');
        await Future.delayed(Duration.zero);
        expect(isolate.synthesizeRequests, hasLength(1));

        isolate.emitWorkerDied('worker crashed: RangeError');
        final result = await synthFuture
            .timeout(const Duration(seconds: 1), onTimeout: () {
          fail('synthesize hung after worker death (F144 regression)');
        });

        expect(result, isNull, reason: 'return contract must stay nullable');
        final warnings = records
            .where((r) =>
                r.level == Level.WARNING &&
                r.loggerName == 'tts.session.test.death.synth')
            .toList();
        expect(warnings, isNotEmpty);
        expect(warnings.first.message, contains('worker crashed'));
      } finally {
        await sub.cancel();
        await session.dispose();
      }
    });

    test(
        'ensureModelLoaded resolves with false and logs WARNING when worker '
        'dies mid-load (F144)', () async {
      final isolate = _FakeTtsIsolate();
      isolate.blockModelLoad = true; // never replies on its own
      final logger = Logger('tts.session.test.death.load');
      final session = TtsSession(isolate: isolate, logger: logger);

      final records = <LogRecord>[];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(records.add);

      try {
        final loadFuture = session.ensureModelLoaded(_qwen3());
        await Future.delayed(Duration.zero);
        expect(isolate.loadModelCalls, hasLength(1));

        isolate.emitWorkerDied('worker crashed during load');
        final result = await loadFuture
            .timeout(const Duration(seconds: 1), onTimeout: () {
          fail('ensureModelLoaded hung after worker death (F144 regression)');
        });

        expect(result, isFalse, reason: 'return contract must stay bool');
        final warnings = records
            .where((r) =>
                r.level == Level.WARNING &&
                r.loggerName == 'tts.session.test.death.load')
            .toList();
        expect(warnings, isNotEmpty);
        expect(warnings.first.message, contains('worker crashed during load'));
      } finally {
        await sub.cancel();
        await session.dispose();
      }
    });

    test(
        'ensureModelLoaded times out to false with WARNING when no response '
        'arrives (F144 backstop)', () async {
      final isolate = _FakeTtsIsolate();
      isolate.blockModelLoad = true; // worker alive but stuck, never replies
      final logger = Logger('tts.session.test.timeout');
      final session = TtsSession(
        isolate: isolate,
        logger: logger,
        modelLoadTimeout: const Duration(milliseconds: 100),
      );

      final records = <LogRecord>[];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(records.add);

      try {
        final result = await session.ensureModelLoaded(_qwen3());

        expect(result, isFalse);
        final warnings = records
            .where((r) =>
                r.level == Level.WARNING &&
                r.loggerName == 'tts.session.test.timeout')
            .toList();
        expect(warnings, isNotEmpty,
            reason: 'timeout must be logged for field diagnosis');
      } finally {
        await sub.cancel();
        await session.dispose();
      }
    });

    test('ensureModelLoaded succeeds before timeout returns true', () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(
        isolate: isolate,
        modelLoadTimeout: const Duration(seconds: 5),
      );

      final result = await session.ensureModelLoaded(_qwen3());
      expect(result, isTrue);
      await session.dispose();
    });

    test(
        'synthesize after a prior worker death fails fast with null, not a '
        'second hang (F144 follow-up)', () async {
      final isolate = _FakeTtsIsolate();
      isolate.autoSucceedSynthesis = false;
      final session = TtsSession(isolate: isolate);
      await session.ensureModelLoaded(_qwen3());

      // First synthesis: worker dies mid-flight.
      final first = session.synthesize(text: 'first');
      await Future.delayed(Duration.zero);
      isolate.emitWorkerDied('crash');
      expect(await first, isNull);

      // Second synthesis on the now-dead session must NOT hang waiting for a
      // WorkerDiedResponse that will never be re-emitted.
      final second = await session.synthesize(text: 'second').timeout(
            const Duration(seconds: 1),
            onTimeout: () => fail('synthesize hung after worker already died'),
          );
      expect(second, isNull);
      await session.dispose();
    });

    test(
        'ensureModelLoaded after a prior worker death fails fast with false',
        () async {
      final isolate = _FakeTtsIsolate();
      final session = TtsSession(isolate: isolate);
      await session.ensureModelLoaded(_qwen3());

      isolate.emitWorkerDied('crash while idle');
      await Future.delayed(Duration.zero);

      // Same config would normally short-circuit to true; a dead worker must
      // not be reported as loaded.
      final result = await session.ensureModelLoaded(_qwen3()).timeout(
            const Duration(seconds: 1),
            onTimeout: () => fail('ensureModelLoaded hung after worker died'),
          );
      expect(result, isFalse);
      await session.dispose();
    });

    test('ensureModelLoaded returns false (not throws) when spawn fails',
        () async {
      final isolate = _FakeTtsIsolate()..spawnThrows = true;
      final session = TtsSession(isolate: isolate);

      final result = await session.ensureModelLoaded(_qwen3());
      expect(result, isFalse,
          reason: 'a spawn-time worker death must surface as false, not throw '
              'or hang');
      await session.dispose();
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

IrodoriEngineConfig _irodori() => const IrodoriEngineConfig(
      modelDir: '/i/m',
      sampleRate: 48000,
      speakerGuidanceScale: 5.0,
      captionGuidanceScale: 3.0,
      numInferenceSteps: 40,
    );

PiperEngineConfig _piper() => const PiperEngineConfig(
      modelDir: '/p/m.onnx',
      sampleRate: 22050,
      dicDir: '/p/dic',
      lengthScale: 0.9,
      noiseScale: 0.5,
      noiseW: 0.7,
    );
