import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/data/tts_isolate.dart';
import 'package:novel_viewer/features/tts/data/tts_language.dart';

/// Fake abort handle that records lifecycle calls, so the F111 handle behaviour
/// can be verified without the native library.
class _FakeAbortHandle implements TtsAbortHandle {
  _FakeAbortHandle(this.address);

  @override
  final int address;

  int abortCount = 0;
  int freeCount = 0;

  @override
  void abort() => abortCount++;

  @override
  void free() => freeCount++;
}

/// Factory that hands out [_FakeAbortHandle]s with a fixed address and records
/// how many handles were created across a session.
class _FakeAbortHandleFactory {
  final int address = 0x1234;

  final List<_FakeAbortHandle> created = [];

  TtsAbortHandle create() {
    final handle = _FakeAbortHandle(address);
    created.add(handle);
    return handle;
  }
}

void main() {
  group('TtsIsolateMessage', () {
    test('LoadModelMessage holds model directory and thread count', () {
      final msg = LoadModelMessage(modelDir: '/path/to/models', nThreads: 8);
      expect(msg.modelDir, '/path/to/models');
      expect(msg.nThreads, 8);
    });

    test('LoadModelMessage holds languageId with explicit value', () {
      final msg = LoadModelMessage(
        modelDir: '/path/to/models',
        languageId: 2050,
      );
      expect(msg.languageId, 2050);
    });

    test('LoadModelMessage defaults languageId to Japanese', () {
      final msg = LoadModelMessage(modelDir: '/path/to/models');
      expect(msg.languageId, TtsLanguage.ja.languageId);
    });

    test('LoadModelMessage defaults engineType to qwen3', () {
      final msg = LoadModelMessage(modelDir: '/path/to/models');
      expect(msg.engineType, TtsEngineType.qwen3);
    });

    test('LoadModelMessage holds piper engine type and params', () {
      final msg = LoadModelMessage(
        modelDir: '/path/to/model.onnx',
        engineType: TtsEngineType.piper,
        dicDir: '/path/to/dic',
        lengthScale: 0.8,
        noiseScale: 0.5,
        noiseW: 0.6,
      );
      expect(msg.engineType, TtsEngineType.piper);
      expect(msg.dicDir, '/path/to/dic');
      expect(msg.lengthScale, 0.8);
      expect(msg.noiseScale, 0.5);
      expect(msg.noiseW, 0.6);
    });

    test('SynthesizeMessage holds text', () {
      final msg = SynthesizeMessage(text: 'こんにちは');
      expect(msg.text, 'こんにちは');
      expect(msg.refWavPath, isNull);
    });

    test('SynthesizeMessage holds text and wav path', () {
      final msg = SynthesizeMessage(
        text: 'こんにちは',
        refWavPath: '/path/to/ref.wav',
      );
      expect(msg.text, 'こんにちは');
      expect(msg.refWavPath, '/path/to/ref.wav');
    });

    test('DisposeMessage is a simple marker', () {
      final msg = DisposeMessage();
      expect(msg, isNotNull);
    });
  });

  group('TtsIsolateResponse', () {
    test('ModelLoadedResponse indicates success', () {
      final response = ModelLoadedResponse(success: true);
      expect(response.success, isTrue);
      expect(response.error, isNull);
    });

    test('ModelLoadedResponse indicates failure with error', () {
      final response = ModelLoadedResponse(
        success: false,
        error: 'model not found',
      );
      expect(response.success, isFalse);
      expect(response.error, 'model not found');
    });

    test('SynthesisResultResponse holds audio data', () {
      final audio = Float32List.fromList([0.1, 0.2, 0.3]);
      final response = SynthesisResultResponse(
        audio: audio,
        sampleRate: 24000,
      );
      expect(response.audio!.length, 3);
      expect(response.sampleRate, 24000);
      expect(response.error, isNull);
    });

    test('SynthesisResultResponse holds error', () {
      final response = SynthesisResultResponse(
        audio: null,
        sampleRate: 0,
        error: 'synthesis failed',
      );
      expect(response.audio, isNull);
      expect(response.error, 'synthesis failed');
    });
  });

  group('TtsIsolate - graceful shutdown', () {
    test('dispose returns Future<void>', () {
      final ttsIsolate = TtsIsolate();
      // dispose() must return Future<void> (not void)
      final result = ttsIsolate.dispose();
      expect(result, isA<Future<void>>());
    });

    test('spawn and dispose completes gracefully', () async {
      final ttsIsolate = TtsIsolate();
      await ttsIsolate.spawn();
      // Should complete without error (isolate processes DisposeMessage and exits)
      await ttsIsolate.dispose();
    });

    test('dispose without spawn completes safely', () async {
      final ttsIsolate = TtsIsolate();
      await ttsIsolate.dispose();
    });

    test('double dispose is safe', () async {
      final ttsIsolate = TtsIsolate();
      await ttsIsolate.spawn();
      await ttsIsolate.dispose();
      await ttsIsolate.dispose();
    });

    test('dispose completes within timeout', () async {
      final ttsIsolate = TtsIsolate();
      await ttsIsolate.spawn();

      // Dispose should complete well within the 2 second timeout
      await ttsIsolate.dispose().timeout(const Duration(seconds: 3));
    });
  });

  group('TtsIsolate - abort handle lifecycle (F111)', () {
    test('spawn creates exactly one abort handle, available before loadModel',
        () async {
      final factory = _FakeAbortHandleFactory();
      final iso = TtsIsolate(abortHandleFactory: factory.create);

      await iso.spawn();

      expect(factory.created, hasLength(1));
      expect(iso.debugAbortHandleAddress, factory.address);

      await iso.dispose();
    });

    test('abort target address is stable across model reloads', () async {
      final factory = _FakeAbortHandleFactory();
      final iso = TtsIsolate(abortHandleFactory: factory.create);
      await iso.spawn();

      final addrBefore = iso.debugAbortHandleAddress;

      // Reload / switch models several times. The worker will fail to load
      // (no native library in tests) but that is irrelevant: the abort target
      // must not depend on any per-context address.
      iso.loadModel('/nonexistent/model-a');
      iso.loadModel('/nonexistent/model-b', engineType: TtsEngineType.piper);
      iso.loadModel('/nonexistent/model-c');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final addrAfter = iso.debugAbortHandleAddress;

      expect(addrBefore, isNotNull);
      expect(addrAfter, addrBefore, reason: 'handle address must be stable');
      expect(factory.created, hasLength(1),
          reason: 'reloads must not create new handles');

      iso.abort();
      expect(factory.created.single.abortCount, 1);

      await iso.dispose();
    });

    test('abort before any loadModel is safe (handle exists at spawn)',
        () async {
      final factory = _FakeAbortHandleFactory();
      final iso = TtsIsolate(abortHandleFactory: factory.create);
      await iso.spawn();

      iso.abort();

      expect(factory.created.single.abortCount, 1);

      await iso.dispose();
    });

    test('dispose frees the abort handle (after worker termination)', () async {
      final factory = _FakeAbortHandleFactory();
      final iso = TtsIsolate(abortHandleFactory: factory.create);
      await iso.spawn();

      expect(factory.created.single.freeCount, 0,
          reason: 'handle must not be freed before dispose');

      await iso.dispose();

      expect(factory.created.single.freeCount, 1);
    });

    test('dispose without spawn does not create or free a handle', () async {
      final factory = _FakeAbortHandleFactory();
      final iso = TtsIsolate(abortHandleFactory: factory.create);

      await iso.dispose();

      expect(factory.created, isEmpty);
    });
  });

  group('TtsIsolate - worker death detection (F144)', () {
    test('worker uncaught error emits a WorkerDiedResponse', () async {
      final iso = TtsIsolate();
      await iso.spawn();

      final deaths = <WorkerDiedResponse>[];
      final sub = iso.responses.listen((r) {
        if (r is WorkerDiedResponse) deaths.add(r);
      });

      iso.debugCrashWorker();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(deaths, hasLength(1),
          reason: 'an abnormally terminated worker must surface a death signal');

      await sub.cancel();
      await iso.dispose();
    });

    test('error and exit listeners coalesce to a single WorkerDiedResponse',
        () async {
      final iso = TtsIsolate();
      await iso.spawn();

      final deaths = <WorkerDiedResponse>[];
      final sub = iso.responses.listen((r) {
        if (r is WorkerDiedResponse) deaths.add(r);
      });

      // A fatal uncaught error fires BOTH addErrorListener and
      // addOnExitListener; the death signal must still be emitted only once.
      iso.debugCrashWorker();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(deaths, hasLength(1));

      await sub.cancel();
      await iso.dispose();
    });

    test('normal dispose does not emit WorkerDiedResponse', () async {
      final iso = TtsIsolate();
      await iso.spawn();

      final deaths = <WorkerDiedResponse>[];
      final sub = iso.responses.listen((r) {
        if (r is WorkerDiedResponse) deaths.add(r);
      });

      await iso.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(deaths, isEmpty,
          reason: 'graceful dispose is not an abnormal worker death');

      await sub.cancel();
    });

    test('worker death path still frees the abort handle on dispose', () async {
      final factory = _FakeAbortHandleFactory();
      final iso = TtsIsolate(abortHandleFactory: factory.create);
      await iso.spawn();

      iso.debugCrashWorker();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      await iso.dispose();

      expect(factory.created.single.freeCount, 1,
          reason: 'a Dart-level worker death leaves no native call in flight, '
              'so the handle is safe to free (no F111 regression)');
    });
  });
}
