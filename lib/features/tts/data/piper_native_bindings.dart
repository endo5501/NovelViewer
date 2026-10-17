import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'tts_engine.dart';

// Bindings for upstream piper-plus's official C API (src/cpp/piper_plus.h,
// PIPER_PLUS_API_VERSION 1). The struct layouts below mirror that header field
// for field, reserved arrays included; piper_native_bindings_test pins their
// sizes against the C compiler's sizeof().

/// The `PIPER_PLUS_API_VERSION` these bindings were written against.
const piperPlusApiVersion = 1;

/// `PiperPlusStatus.PIPER_PLUS_OK`.
const piperPlusOk = 0;

final class PiperPlusConfig extends Struct {
  /// Required: `.onnx` model file path (UTF-8).
  external Pointer<Utf8> modelPath;

  /// Optional: `.json` config path (NULL = model_path + ".json").
  external Pointer<Utf8> configPath;

  /// Optional: "cpu", "cuda", "coreml", "directml" (NULL = "cpu").
  external Pointer<Utf8> provider;

  /// ONNX intra-op threads (0 = auto).
  @Int32()
  external int numThreads;

  /// GPU device index (ignored for cpu).
  @Int32()
  external int gpuDeviceId;

  /// Optional: OpenJTalk dictionary directory (NULL = auto-detect).
  external Pointer<Utf8> dictDir;

  /// Must be zero.
  @Array(7)
  external Array<Int32> reserved;
}

final class PiperPlusSynthOptions extends Struct {
  @Int32()
  external int speakerId;

  /// Language index (-1 = auto-detect).
  @Int32()
  external int languageId;

  @Float()
  external double noiseScale;

  @Float()
  external double lengthScale;

  @Float()
  external double noiseW;

  @Float()
  external double sentenceSilenceSec;

  /// Voice cloning embedding (NULL = use speaker_id).
  external Pointer<Float> speakerEmbedding;

  @Int32()
  external int speakerEmbeddingDim;

  /// Must be zero.
  @Array(5)
  external Array<Int32> reserved;
}

final class PiperPlusPhonemeResult extends Struct {
  /// BORROWED: space-separated phoneme string, valid until the next
  /// phonemize or synthesis call on the same engine.
  external Pointer<Utf8> phonemes;

  /// BORROWED: detected/resolved language code.
  external Pointer<Utf8> language;

  @Int32()
  external int numPhonemes;

  /// Must be zero.
  @Array(4)
  external Array<Int32> reserved;
}

// int32_t piper_plus_api_version(void)
typedef _PApiVersionC = Int32 Function();
typedef _PApiVersionDart = int Function();

// const char *piper_plus_get_last_error(void)
typedef _PGetLastErrorC = Pointer<Utf8> Function();
typedef _PGetLastErrorDart = Pointer<Utf8> Function();

// PiperPlusStatus piper_plus_create(const PiperPlusConfig *, PiperPlusEngine **)
typedef _PCreateC =
    Int32 Function(Pointer<PiperPlusConfig>, Pointer<Pointer<Void>>);
typedef _PCreateDart =
    int Function(Pointer<PiperPlusConfig>, Pointer<Pointer<Void>>);

// void piper_plus_free(PiperPlusEngine *)
typedef _PFreeC = Void Function(Pointer<Void>);
typedef _PFreeDart = void Function(Pointer<Void>);

// PiperPlusSynthOptions piper_plus_default_options(void)
typedef _PDefaultOptionsC = PiperPlusSynthOptions Function();
typedef _PDefaultOptionsDart = PiperPlusSynthOptions Function();

// PiperPlusStatus piper_plus_synthesize(engine, text, opts,
//     float **out_samples, int32_t *out_num_samples, int32_t *out_sample_rate)
typedef _PSynthesizeC =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<PiperPlusSynthOptions>,
      Pointer<Pointer<Float>>,
      Pointer<Int32>,
      Pointer<Int32>,
    );
typedef _PSynthesizeDart =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<PiperPlusSynthOptions>,
      Pointer<Pointer<Float>>,
      Pointer<Int32>,
      Pointer<Int32>,
    );

// void piper_plus_free_audio(float *samples)
typedef _PFreeAudioC = Void Function(Pointer<Float>);
typedef _PFreeAudioDart = void Function(Pointer<Float>);

// int32_t piper_plus_sample_rate(const PiperPlusEngine *)
typedef _PSampleRateC = Int32 Function(Pointer<Void>);
typedef _PSampleRateDart = int Function(Pointer<Void>);

// int32_t piper_plus_language_id(const PiperPlusEngine *, const char *)
typedef _PLanguageIdC = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef _PLanguageIdDart = int Function(Pointer<Void>, Pointer<Utf8>);

// PiperPlusStatus piper_plus_phonemize(engine, text, language,
//     PiperPlusPhonemeResult *out_result)
typedef _PPhonemizeC =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<PiperPlusPhonemeResult>,
    );
typedef _PPhonemizeDart =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<PiperPlusPhonemeResult>,
    );

class PiperNativeBindings {
  PiperNativeBindings(DynamicLibrary library) : _library = library;

  factory PiperNativeBindings.open() => PiperNativeBindings(
    openLibrary(libraryName, operatingSystem: Platform.operatingSystem),
  );

  /// Opens the native library [name], or throws a [TtsEngineException] that
  /// says which library is missing and how to build it.
  ///
  /// The library is built separately from the app — on iOS it is not even
  /// tracked by Git — so a build that skipped that step is a real case, and
  /// the dynamic loader's own error names neither the step nor the script.
  /// Its text is kept after the explanation, for diagnosis.
  static DynamicLibrary openLibrary(
    String name, {
    required String operatingSystem,
  }) {
    try {
      return DynamicLibrary.open(name);
    } on ArgumentError catch (e) {
      throw TtsEngineException(
        'Piper native library $name is not in this build. '
        '${buildInstructionsFor(operatingSystem)} (${e.message})',
      );
    }
  }

  /// How to produce the Piper native library for [operatingSystem] (a
  /// `Platform.operatingSystem` value).
  static String buildInstructionsFor(String operatingSystem) {
    return switch (operatingSystem) {
      'ios' =>
        'Build it with scripts/build_piper_ios.sh, then rebuild the app.',
      'macos' =>
        'Build it with scripts/build_piper_macos.sh, then rebuild the app.',
      'windows' =>
        r'Build it with scripts\build_piper_windows.bat, then rebuild the app.',
      _ => 'Piper is not built for $operatingSystem.',
    };
  }

  final DynamicLibrary _library;

  static String get libraryName => libraryNameFor(Platform.operatingSystem);

  /// The name [DynamicLibrary.open] takes on [operatingSystem] (a
  /// `Platform.operatingSystem` value).
  ///
  /// iOS accepts native code only as a signed framework inside the app, so the
  /// binary is reached through `piper_plus.framework`, which the runtime
  /// resolves against the app's `@executable_path/Frameworks` rpath. ONNX
  /// Runtime is linked into that binary rather than shipped beside it.
  static String libraryNameFor(String operatingSystem) {
    return switch (operatingSystem) {
      'macos' => 'libpiper_plus.dylib',
      'windows' => 'piper_plus.dll',
      'ios' => 'piper_plus.framework/piper_plus',
      _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
    };
  }

  late final apiVersion = _library
      .lookupFunction<_PApiVersionC, _PApiVersionDart>(
        'piper_plus_api_version',
      );

  /// The message is stored thread-locally by the native library: read it
  /// synchronously right after the failing call, with no `await` in between.
  late final getLastError = _library
      .lookupFunction<_PGetLastErrorC, _PGetLastErrorDart>(
        'piper_plus_get_last_error',
      );

  late final create = _library.lookupFunction<_PCreateC, _PCreateDart>(
    'piper_plus_create',
  );

  late final free = _library.lookupFunction<_PFreeC, _PFreeDart>(
    'piper_plus_free',
  );

  late final defaultOptions = _library
      .lookupFunction<_PDefaultOptionsC, _PDefaultOptionsDart>(
        'piper_plus_default_options',
      );

  /// The returned sample buffer is owned by the caller and must be released
  /// with [freeAudio].
  late final synthesize = _library
      .lookupFunction<_PSynthesizeC, _PSynthesizeDart>('piper_plus_synthesize');

  late final freeAudio = _library.lookupFunction<_PFreeAudioC, _PFreeAudioDart>(
    'piper_plus_free_audio',
  );

  late final sampleRate = _library
      .lookupFunction<_PSampleRateC, _PSampleRateDart>(
        'piper_plus_sample_rate',
      );

  /// Returns -1 when the model has no entry for the language name.
  late final languageId = _library
      .lookupFunction<_PLanguageIdC, _PLanguageIdDart>(
        'piper_plus_language_id',
      );

  /// Phonemizes without synthesizing. The result's strings are borrowed from
  /// the engine: copy them before the next call on the same engine.
  late final phonemize = _library.lookupFunction<_PPhonemizeC, _PPhonemizeDart>(
    'piper_plus_phonemize',
  );
}
