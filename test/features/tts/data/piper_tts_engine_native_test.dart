import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/piper_native_bindings.dart';
import 'package:novel_viewer/features/tts/data/piper_tts_engine.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';

// Runs PiperTtsEngine against the built libpiper_plus.dylib and a real model,
// pinning upstream behavior the engine works around (language detection of
// kana-less kanji, inference on an empty id sequence). Needs a model, so it
// only runs when one is supplied:
//
//   PIPER_TEST_MODEL=<dir>/tsukuyomi-chan-6lang-fp16.onnx \
//   PIPER_TEST_DIC=<dir>/open_jtalk_dic \
//   fvm flutter test test/features/tts/data/piper_tts_engine_native_test.dart
//
// The model must be the pinned revision (PiperModelDownloadService
// .modelRevision) with its config next to it as `<model>.onnx.json`.
void main() {
  final modelPath = Platform.environment['PIPER_TEST_MODEL'];
  final dicDir = Platform.environment['PIPER_TEST_DIC'];
  final libPath =
      '${Directory.current.path}/macos/Frameworks/libpiper_plus.dylib';
  final skip = !Platform.isMacOS
      ? 'macOS only'
      : !File(libPath).existsSync()
      ? 'libpiper_plus.dylib not built'
      : modelPath == null || dicDir == null
      ? 'PIPER_TEST_MODEL / PIPER_TEST_DIC not set'
      : null;

  group('PiperTtsEngine with the native library', () {
    late PiperTtsEngine engine;

    setUp(() {
      engine = PiperTtsEngine(PiperNativeBindings(DynamicLibrary.open(libPath)))
        ..loadModel(modelPath!, dicDir: dicDir!)
        ..setLengthScale(1.0)
        ..setNoiseScale(0.667)
        ..setNoiseW(0.8);
    });

    tearDown(() => engine.dispose());

    bool isSilent(TtsSynthesisResult r) => r.audio.every((s) => s == 0);

    test('speaks a kanji-only sentence as Japanese', () {
      // Without a zh-free config, upstream detects this as Chinese and has no
      // phoneme to feed the model.
      final result = engine.synthesize('多分。');

      expect(isSilent(result), isFalse);
    });

    test('phonemizes a kanji-only sentence with Japanese phonemes', () {
      // loadModel wrote the zh-free config the engine hands to the native
      // side; phonemize through it to see which phonemizer picks the text up.
      final bindings = PiperNativeBindings(DynamicLibrary.open(libPath));
      final config = calloc<PiperPlusConfig>();
      final outEngine = calloc<Pointer<Void>>();
      final result = calloc<PiperPlusPhonemeResult>();
      final model = modelPath!.toNativeUtf8();
      final configPath = '$modelPath.ja.json'.toNativeUtf8();
      final dic = dicDir!.toNativeUtf8();
      final text = '多分。'.toNativeUtf8();
      final language = 'ja'.toNativeUtf8();
      try {
        config.ref
          ..modelPath = model
          ..configPath = configPath
          ..dictDir = dic;
        expect(bindings.create(config, outEngine), piperPlusOk);
        try {
          expect(
            bindings.phonemize(outEngine.value, text, language, result),
            piperPlusOk,
          );
          // 「多分」 is "tabun": Japanese phonemes, not the lone "." the
          // Chinese path leaves without a pinyin dictionary.
          expect(result.ref.phonemes.toDartString(), contains('b u'));
          expect(result.ref.language.toDartString(), 'ja');
        } finally {
          bindings.free(outEngine.value);
        }
      } finally {
        for (final p in [model, configPath, dic, text, language]) {
          calloc.free(p);
        }
        calloc.free(result);
        calloc.free(outEngine);
        calloc.free(config);
      }
    });

    test('speaks kanji with kana', () {
      expect(isSilent(engine.synthesize('多分だ。')), isFalse);
    });

    test('returns silence for a symbol-only line', () {
      final result = engine.synthesize('---');

      expect(isSilent(result), isTrue);
      expect(result.audio, hasLength((result.sampleRate * 0.2).round()));
    });

    test('returns silence instead of failing on English-only text', () {
      // No English dictionary is bundled, so upstream drops every word and
      // would run inference on an empty id sequence.
      final result = engine.synthesize('Hello world.');

      expect(isSilent(result), isTrue);
    });
  }, skip: skip);
}
