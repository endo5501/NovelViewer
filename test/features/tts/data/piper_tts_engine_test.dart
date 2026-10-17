// ignore_for_file: prefer_function_declarations_over_variables

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/piper_native_bindings.dart';
import 'package:novel_viewer/features/tts/data/piper_tts_engine.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';

typedef CreateFn =
    int Function(Pointer<PiperPlusConfig>, Pointer<Pointer<Void>>);
typedef SynthesizeFn =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<PiperPlusSynthOptions>,
      Pointer<Pointer<Float>>,
      Pointer<Int32>,
      Pointer<Int32>,
    );

/// Snapshot of the options struct the engine passed to one synthesize call.
class SynthCall {
  SynthCall(this.text, PiperPlusSynthOptions opts)
    : languageId = opts.languageId,
      lengthScale = opts.lengthScale,
      noiseScale = opts.noiseScale,
      noiseW = opts.noiseW;

  final String text;
  final int languageId;
  final double lengthScale;
  final double noiseScale;
  final double noiseW;
}

/// Mock bindings for testing PiperTtsEngine without loading native library.
///
/// Mirrors the piper_plus.h contract: create writes the engine handle through
/// an out-pointer, synthesize hands back a caller-owned buffer that must be
/// released with freeAudio, and errors are read through getLastError.
class MockPiperNativeBindings extends PiperNativeBindings {
  MockPiperNativeBindings() : super(DynamicLibrary.process());

  static final _fakeEngine = Pointer<Void>.fromAddress(0x1234);

  // --- configurable behavior ---
  int reportedApiVersion = 1;
  int createStatus = 0;
  int synthesizeStatus = 0;
  String lastError = '';
  Map<String, int> languageMap = {'ja': 0, 'en': 1};
  int fakeSampleRate = 22050;
  Float32List fakeAudio = Float32List.fromList([0.1, 0.2, -0.3]);

  /// When true, synthesize reports success with a non-null buffer but zero
  /// samples.
  bool returnEmptyBuffer = false;

  // --- recorded calls ---
  int createCalls = 0;
  String? lastModelPath;
  String? lastConfigPath;
  String? lastDictDir;
  final List<Pointer<Void>> freedEngines = [];
  final List<SynthCall> synthCalls = [];
  final List<Pointer<Float>> returnedBuffers = [];
  final List<Pointer<Float>> freedBuffers = [];

  late final Pointer<PiperPlusSynthOptions> _defaults = () {
    final p = calloc<PiperPlusSynthOptions>();
    p.ref
      ..speakerId = 0
      ..languageId = -1
      ..noiseScale = 0.4
      ..lengthScale = 1.0
      ..noiseW = 0.5
      ..sentenceSilenceSec = 0.2
      ..speakerEmbedding = nullptr
      ..speakerEmbeddingDim = 0;
    return p;
  }();

  @override
  // ignore: overridden_fields
  late final int Function() apiVersion = () => reportedApiVersion;

  @override
  // ignore: overridden_fields
  late final Pointer<Utf8> Function() getLastError = () =>
      lastError.toNativeUtf8();

  @override
  // ignore: overridden_fields
  late final CreateFn create =
      (Pointer<PiperPlusConfig> config, Pointer<Pointer<Void>> out) {
        createCalls++;
        final c = config.ref;
        lastModelPath = c.modelPath.toDartString();
        lastConfigPath = c.configPath == nullptr
            ? null
            : c.configPath.toDartString();
        lastDictDir = c.dictDir == nullptr ? null : c.dictDir.toDartString();
        if (createStatus != 0) {
          out.value = nullptr;
          return createStatus;
        }
        out.value = _fakeEngine;
        return 0;
      };

  @override
  // ignore: overridden_fields
  late final void Function(Pointer<Void>) free = (Pointer<Void> engine) {
    freedEngines.add(engine);
  };

  @override
  // ignore: overridden_fields
  late final PiperPlusSynthOptions Function() defaultOptions = () =>
      _defaults.ref;

  @override
  // ignore: overridden_fields
  late final SynthesizeFn synthesize =
      (
        Pointer<Void> engine,
        Pointer<Utf8> text,
        Pointer<PiperPlusSynthOptions> opts,
        Pointer<Pointer<Float>> outSamples,
        Pointer<Int32> outNumSamples,
        Pointer<Int32> outSampleRate,
      ) {
        synthCalls.add(SynthCall(text.toDartString(), opts.ref));
        if (synthesizeStatus != 0) {
          outSamples.value = nullptr;
          outNumSamples.value = 0;
          return synthesizeStatus;
        }
        final length = returnEmptyBuffer ? 0 : fakeAudio.length;
        final buffer = calloc<Float>(length == 0 ? 1 : length);
        for (var i = 0; i < length; i++) {
          buffer[i] = fakeAudio[i];
        }
        returnedBuffers.add(buffer);
        outSamples.value = buffer;
        outNumSamples.value = length;
        outSampleRate.value = fakeSampleRate;
        return 0;
      };

  @override
  // ignore: overridden_fields
  late final void Function(Pointer<Float>) freeAudio =
      (Pointer<Float> samples) {
        freedBuffers.add(samples);
        // Overwrite before releasing so a result that still aliases native
        // memory would visibly change.
        samples[0] = 99.0;
      };

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>) sampleRate = (Pointer<Void> engine) =>
      fakeSampleRate;

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>, Pointer<Utf8>) languageId =
      (Pointer<Void> engine, Pointer<Utf8> name) =>
          languageMap[name.toDartString()] ?? -1;
}

void main() {
  group('PiperTtsEngine', () {
    late MockPiperNativeBindings mockBindings;
    late PiperTtsEngine engine;

    setUp(() {
      mockBindings = MockPiperNativeBindings();
      engine = PiperTtsEngine(mockBindings);
    });

    void load() => engine.loadModel('/fake/model.onnx', dicDir: '/fake/dic');

    group('loadModel', () {
      test('isLoaded returns false before loading model', () {
        expect(engine.isLoaded, false);
      });

      test('loads the model, its sibling config and the dictionary', () {
        load();

        expect(engine.isLoaded, true);
        expect(mockBindings.lastModelPath, '/fake/model.onnx');
        expect(mockBindings.lastConfigPath, '/fake/model.onnx.json');
        expect(mockBindings.lastDictDir, '/fake/dic');
      });

      test('throws with the native error message when create fails', () {
        mockBindings
          ..createStatus = -2
          ..lastError = 'Failed to load model: no such file';

        expect(
          () => engine.loadModel('nonexistent.onnx', dicDir: '/fake/dic'),
          throwsA(
            isA<TtsEngineException>().having(
              (e) => e.message,
              'message',
              contains('Failed to load model: no such file'),
            ),
          ),
        );
        expect(engine.isLoaded, false);
      });

      test('rejects a library reporting a different C API version', () {
        mockBindings.reportedApiVersion = 2;

        expect(
          load,
          throwsA(
            isA<TtsEngineException>().having(
              (e) => e.message,
              'message',
              allOf(contains('1'), contains('2')),
            ),
          ),
        );
        expect(mockBindings.createCalls, 0);
        expect(engine.isLoaded, false);
      });

      test('reloading frees the previous engine', () {
        load();
        load();

        expect(mockBindings.freedEngines, hasLength(1));
        expect(engine.isLoaded, true);
      });
    });

    group('synthesize', () {
      test('returns a TtsSynthesisResult with the native audio', () {
        mockBindings.fakeSampleRate = 22050;
        load();

        final result = engine.synthesize('テスト');

        expect(result, isA<TtsSynthesisResult>());
        expect(result.audio, hasLength(3));
        expect(result.audio[0], closeTo(0.1, 1e-6));
        expect(result.sampleRate, 22050);
        expect(mockBindings.synthCalls.single.text, 'テスト');
      });

      test('throws without calling native synthesis when not loaded', () {
        expect(
          () => engine.synthesize('テスト'),
          throwsA(isA<TtsEngineException>()),
        );
        expect(mockBindings.synthCalls, isEmpty);
      });

      test('throws with the native error message when synthesis fails', () {
        load();
        mockBindings
          ..synthesizeStatus = -4
          ..lastError = 'Text phonemization failed';

        expect(
          () => engine.synthesize('テスト'),
          throwsA(
            isA<TtsEngineException>().having(
              (e) => e.message,
              'message',
              contains('Text phonemization failed'),
            ),
          ),
        );
      });
    });

    group('audio buffer ownership', () {
      test('releases the returned buffer exactly once after copying', () {
        load();

        final result = engine.synthesize('テスト');

        expect(mockBindings.freedBuffers, hasLength(1));
        expect(
          mockBindings.freedBuffers.single,
          mockBindings.returnedBuffers.single,
        );
        // The mock scribbles over the buffer on release; the result must be
        // an independent copy.
        expect(result.audio[0], closeTo(0.1, 1e-6));
      });

      test('releases the buffer when the result has zero samples', () {
        load();
        mockBindings.returnEmptyBuffer = true;

        expect(
          () => engine.synthesize('テスト'),
          throwsA(isA<TtsEngineException>()),
        );
        expect(mockBindings.freedBuffers, hasLength(1));
        expect(
          mockBindings.freedBuffers.single,
          mockBindings.returnedBuffers.single,
        );
      });
    });

    group('synthesis parameters', () {
      test('parameters persist across multiple syntheses', () {
        load();
        engine
          ..setLengthScale(1.5)
          ..setNoiseScale(0.3)
          ..setNoiseW(0.6);

        engine.synthesize('一');
        engine.synthesize('二');

        expect(mockBindings.synthCalls, hasLength(2));
        for (final call in mockBindings.synthCalls) {
          expect(call.lengthScale, closeTo(1.5, 1e-6));
          expect(call.noiseScale, closeTo(0.3, 1e-6));
          expect(call.noiseW, closeTo(0.6, 1e-6));
        }
      });

      test('unset parameters use the upstream defaults', () {
        load();
        engine.setLengthScale(0.8);

        engine.synthesize('テスト');

        final call = mockBindings.synthCalls.single;
        expect(call.lengthScale, closeTo(0.8, 1e-6));
        expect(call.noiseScale, closeTo(0.4, 1e-6));
        expect(call.noiseW, closeTo(0.5, 1e-6));
      });

      test('setLengthScale throws when model not loaded', () {
        expect(
          () => engine.setLengthScale(1.0),
          throwsA(isA<TtsEngineException>()),
        );
      });
    });

    group('synthesis language', () {
      test('passes the Japanese language id when the model has ja', () {
        mockBindings.languageMap = {'ja': 0, 'en': 1};
        load();

        engine.synthesize('テスト');

        expect(mockBindings.synthCalls.single.languageId, 0);
      });

      test('falls back to auto-detection when the model has no ja', () {
        mockBindings.languageMap = {};
        load();

        engine.synthesize('テスト');

        expect(mockBindings.synthCalls.single.languageId, -1);
      });
    });

    group('dispose', () {
      test('frees the native engine and clears isLoaded', () {
        load();

        engine.dispose();

        expect(mockBindings.freedEngines, hasLength(1));
        expect(engine.isLoaded, false);
      });

      test('is a no-op when nothing is loaded', () {
        engine.dispose();

        expect(mockBindings.freedEngines, isEmpty);
        expect(engine.isLoaded, false);
      });
    });
  });
}
