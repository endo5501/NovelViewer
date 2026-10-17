// ignore_for_file: prefer_function_declarations_over_variables

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
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

typedef PhonemizeFn =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<PiperPlusPhonemeResult>,
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

  /// Space-separated phonemes piper_plus_phonemize reports for any text.
  String phonemizeOutput = 't a';

  // --- recorded calls ---
  int createCalls = 0;
  String? lastModelPath;
  String? lastConfigPath;
  String? lastDictDir;
  final List<Pointer<Void>> freedEngines = [];
  final List<SynthCall> synthCalls = [];
  final List<Pointer<Float>> returnedBuffers = [];
  final List<Pointer<Float>> freedBuffers = [];
  final List<String> phonemizedTexts = [];
  final List<String?> phonemizeLanguages = [];

  final List<Pointer<Utf8>> _errorStrings = [];

  /// Releases the native memory the mock itself allocated. Buffers handed to
  /// the engine are released through [freeAudio], as the real API requires.
  void releaseNative() {
    calloc.free(_defaults);
    _errorStrings.forEach(calloc.free);
    _errorStrings.clear();
    _phonemeStrings.forEach(calloc.free);
    _phonemeStrings.clear();
  }

  final List<Pointer<Utf8>> _phonemeStrings = [];

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
  late final Pointer<Utf8> Function() getLastError = () {
    final message = lastError.toNativeUtf8();
    _errorStrings.add(message);
    return message;
  };

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
        calloc.free(samples);
      };

  @override
  // ignore: overridden_fields
  late final int Function(Pointer<Void>) sampleRate = (Pointer<Void> engine) =>
      fakeSampleRate;

  @override
  // ignore: overridden_fields
  late final PhonemizeFn phonemize =
      (
        Pointer<Void> engine,
        Pointer<Utf8> text,
        Pointer<Utf8> language,
        Pointer<PiperPlusPhonemeResult> out,
      ) {
        phonemizedTexts.add(text.toDartString());
        phonemizeLanguages.add(
          language == nullptr ? null : language.toDartString(),
        );
        final phonemes = phonemizeOutput.toNativeUtf8();
        final lang = 'ja'.toNativeUtf8();
        _phonemeStrings
          ..add(phonemes)
          ..add(lang);
        out.ref
          ..phonemes = phonemes
          ..language = lang
          ..numPhonemes = phonemizeOutput.trim().isEmpty
              ? 0
              : phonemizeOutput.trim().split(' ').length;
        return 0;
      };

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

    tearDown(() => mockBindings.releaseNative());

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

    group('model config', () {
      late Directory tmp;

      setUp(() => tmp = Directory.systemTemp.createTempSync('piper_cfg_'));
      tearDown(() => tmp.deleteSync(recursive: true));

      String writeConfig(Map<String, int> languages) {
        final modelPath = '${tmp.path}/model.onnx';
        File('$modelPath.json').writeAsStringSync(
          jsonEncode({
            'audio': {'sample_rate': 22050},
            'language_id_map': languages,
            'phoneme_id_map': {
              't': [38],
              'a': [10],
            },
          }),
        );
        return modelPath;
      }

      test('hands the native engine a config without zh when ja and zh '
          'coexist', () {
        final modelPath = writeConfig({'ja': 0, 'en': 1, 'zh': 2, 'es': 3});
        final original = File('$modelPath.json').readAsStringSync();

        engine.loadModel(modelPath, dicDir: '/fake/dic');

        expect(mockBindings.lastConfigPath, '$modelPath.ja.json');
        final derived =
            jsonDecode(File('$modelPath.ja.json').readAsStringSync())
                as Map<String, dynamic>;
        expect(derived['language_id_map'], {'ja': 0, 'en': 1, 'es': 3});
        expect(derived['phoneme_id_map'], {
          't': [38],
          'a': [10],
        });
        expect(derived['audio'], {'sample_rate': 22050});
        expect(File('$modelPath.json').readAsStringSync(), original);
      });

      test('uses the downloaded config as-is when there is no zh', () {
        final modelPath = writeConfig({'ja': 0, 'en': 1});

        engine.loadModel(modelPath, dicDir: '/fake/dic');

        expect(mockBindings.lastConfigPath, '$modelPath.json');
        expect(File('$modelPath.ja.json').existsSync(), isFalse);
      });

      test('returns 0.2 s of silence for text with no known phoneme', () {
        final modelPath = writeConfig({'ja': 0, 'zh': 2});
        mockBindings
          ..fakeSampleRate = 22050
          ..phonemizeOutput = '.';
        engine.loadModel(modelPath, dicDir: '/fake/dic');

        final result = engine.synthesize('---');

        expect(mockBindings.synthCalls, isEmpty);
        expect(result.sampleRate, 22050);
        expect(result.audio, hasLength(4410));
        expect(result.audio.every((s) => s == 0), isTrue);
      });

      test('returns silence when phonemization yields nothing', () {
        final modelPath = writeConfig({'ja': 0});
        mockBindings.phonemizeOutput = '';
        engine.loadModel(modelPath, dicDir: '/fake/dic');

        final result = engine.synthesize('…');

        expect(mockBindings.synthCalls, isEmpty);
        expect(result.audio, hasLength(4410));
      });

      test('synthesizes text that has a known phoneme', () {
        final modelPath = writeConfig({'ja': 0, 'zh': 2});
        mockBindings.phonemizeOutput = '. t a';
        engine.loadModel(modelPath, dicDir: '/fake/dic');

        engine.synthesize('多分だ。');

        expect(mockBindings.phonemizedTexts, ['多分だ。']);
        expect(mockBindings.phonemizeLanguages, ['ja']);
        expect(mockBindings.synthCalls.single.text, '多分だ。');
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
