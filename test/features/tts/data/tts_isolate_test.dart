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

/// Factory that hands out per-engine-family [_FakeAbortHandle]s and records how
/// many handles were created across a session. Mirrors the production design:
/// one handle for the qwen3 family and one for the audiocpp (irodori) family,
/// each with its own fixed address; piper has none.
class _FakeAbortHandleFactory {
  final int qwen3Address = 0x1234;
  final int audiocppAddress = 0x5678;

  final List<_FakeAbortHandle> created = [];

  Map<TtsEngineType, TtsAbortHandle> create() {
    final qwen3 = _FakeAbortHandle(qwen3Address);
    final audiocpp = _FakeAbortHandle(audiocppAddress);
    created
      ..add(qwen3)
      ..add(audiocpp);
    return {
      TtsEngineType.qwen3: qwen3,
      TtsEngineType.irodori: audiocpp,
    };
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

    test('LoadModelMessage holds irodori engine type', () {
      final msg = LoadModelMessage(
        modelDir: '/path/to/irodori',
        engineType: TtsEngineType.irodori,
      );
      expect(msg.engineType, TtsEngineType.irodori);
      expect(msg.modelDir, '/path/to/irodori');
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

    test('SynthesizeMessage defaults irodori caption/guidance to null', () {
      final msg = SynthesizeMessage(text: 'こんにちは');
      expect(msg.caption, isNull);
      expect(msg.speakerGuidanceScale, isNull);
      expect(msg.captionGuidanceScale, isNull);
      expect(msg.numInferenceSteps, isNull);
    });

    test('SynthesizeMessage holds irodori caption and guidance params', () {
      final msg = SynthesizeMessage(
        text: 'こんにちは',
        refWavPath: '/path/to/ref.wav',
        caption: '落ち着いた大人の女性の声',
        speakerGuidanceScale: 5.0,
        captionGuidanceScale: 3.0,
        numInferenceSteps: 40,
      );
      expect(msg.caption, '落ち着いた大人の女性の声');
      expect(msg.speakerGuidanceScale, 5.0);
      expect(msg.captionGuidanceScale, 3.0);
      expect(msg.numInferenceSteps, 40);
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
    test('spawn creates per-engine abort handles available before loadModel',
        () async {
      final factory = _FakeAbortHandleFactory();
      final iso = TtsIsolate(abortHandleFactory: factory.create);

      await iso.spawn();

      // One handle per engine family (qwen3 + audiocpp/irodori); piper has none.
      expect(factory.created, hasLength(2));
      expect(iso.debugAbortHandleAddressFor(TtsEngineType.qwen3),
          factory.qwen3Address);
      expect(iso.debugAbortHandleAddressFor(TtsEngineType.irodori),
          factory.audiocppAddress);
      expect(iso.debugAbortHandleAddressFor(TtsEngineType.piper), isNull);

      await iso.dispose();
    });

    test('qwen3 abort target address is stable across model reloads', () async {
      final factory = _FakeAbortHandleFactory();
      final iso = TtsIsolate(abortHandleFactory: factory.create);
      await iso.spawn();

      final addrBefore = iso.debugAbortHandleAddressFor(TtsEngineType.qwen3);

      // Reload / switch models several times. The worker will fail to load
      // (no native library in tests) but that is irrelevant: the abort target
      // for a given engine family must not depend on any per-context address.
      iso.loadModel('/nonexistent/model-a');
      iso.loadModel('/nonexistent/model-b', engineType: TtsEngineType.piper);
      iso.loadModel('/nonexistent/model-c');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final addrAfter = iso.debugAbortHandleAddressFor(TtsEngineType.qwen3);

      expect(addrBefore, isNotNull);
      expect(addrAfter, addrBefore, reason: 'handle address must be stable');
      expect(factory.created, hasLength(2),
          reason: 'reloads must not create new handles');

      iso.abort();
      // abort() sets ALL live handles (harmless for the inactive engine).
      for (final handle in factory.created) {
        expect(handle.abortCount, 1);
      }

      await iso.dispose();
    });

    test('irodori abort target address is stable across an irodori reload',
        () async {
      final factory = _FakeAbortHandleFactory();
      final iso = TtsIsolate(abortHandleFactory: factory.create);
      await iso.spawn();

      final addrBefore = iso.debugAbortHandleAddressFor(TtsEngineType.irodori);

      // Switch between engines including the third (irodori) branch. The
      // worker fails to load (no native library in tests) but the abort
      // target must stay stable and no new handle may be created.
      iso.loadModel('/nonexistent/qwen3');
      iso.loadModel('/nonexistent/irodori',
          engineType: TtsEngineType.irodori);
      iso.loadModel('/nonexistent/qwen3-again');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(iso.debugAbortHandleAddressFor(TtsEngineType.irodori), addrBefore);
      expect(factory.created, hasLength(2),
          reason: 'switching to irodori must not create a new handle');

      iso.abort();
      for (final handle in factory.created) {
        expect(handle.abortCount, 1);
      }

      await iso.dispose();
    });

    test('abort before any loadModel is safe (handles exist at spawn)',
        () async {
      final factory = _FakeAbortHandleFactory();
      final iso = TtsIsolate(abortHandleFactory: factory.create);
      await iso.spawn();

      iso.abort();

      for (final handle in factory.created) {
        expect(handle.abortCount, 1);
      }

      await iso.dispose();
    });

    test('dispose frees all abort handles (after worker termination)',
        () async {
      final factory = _FakeAbortHandleFactory();
      final iso = TtsIsolate(abortHandleFactory: factory.create);
      await iso.spawn();

      for (final handle in factory.created) {
        expect(handle.freeCount, 0,
            reason: 'handles must not be freed before dispose');
      }

      await iso.dispose();

      for (final handle in factory.created) {
        expect(handle.freeCount, 1);
      }
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

    test('worker death path still frees all abort handles on dispose',
        () async {
      final factory = _FakeAbortHandleFactory();
      final iso = TtsIsolate(abortHandleFactory: factory.create);
      await iso.spawn();

      iso.debugCrashWorker();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      await iso.dispose();

      for (final handle in factory.created) {
        expect(handle.freeCount, 1,
            reason: 'a Dart-level worker death leaves no native call in flight, '
                'so the handles are safe to free (no F111 regression)');
      }
    });
  });
}
