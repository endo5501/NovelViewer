import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// audiocpp_create_abort_handle() -> audiocpp_abort_handle*
typedef _AcCreateAbortHandleC = Pointer<Void> Function();
typedef _AcCreateAbortHandleDart = Pointer<Void> Function();

// audiocpp_free_abort_handle(audiocpp_abort_handle*)
typedef _AcFreeAbortHandleC = Void Function(Pointer<Void>);
typedef _AcFreeAbortHandleDart = void Function(Pointer<Void>);

// audiocpp_abort(audiocpp_abort_handle*) — callable from any thread.
typedef _AcAbortC = Void Function(Pointer<Void>);
typedef _AcAbortDart = void Function(Pointer<Void>);

// audiocpp_reset_abort(audiocpp_abort_handle*)
typedef _AcResetAbortC = Void Function(Pointer<Void>);
typedef _AcResetAbortDart = void Function(Pointer<Void>);

// audiocpp_init(model_dir, n_threads, abort_handle) -> audiocpp_ctx*
// The abort handle is owned by the caller and outlives the context (D3/D4).
typedef _AcInitC = Pointer<Void> Function(Pointer<Utf8>, Int32, Pointer<Void>);
typedef _AcInitDart = Pointer<Void> Function(Pointer<Utf8>, int, Pointer<Void>);

typedef _AcIsLoadedC = Int32 Function(Pointer<Void>);
typedef _AcIsLoadedDart = int Function(Pointer<Void>);

typedef _AcFreeC = Void Function(Pointer<Void>);
typedef _AcFreeDart = void Function(Pointer<Void>);

// audiocpp_synthesize(ctx, text, ref_wav_path?, caption?, speaker_guidance_scale,
// caption_guidance_scale, num_inference_steps) -> int (0 == success).
// ref_wav_path / caption are nullable — the NULL combinations select between
// plain TTS / clone-only / caption-only / clone+caption synthesis.
typedef _AcSynthesizeC = Int32 Function(
  Pointer<Void>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Float,
  Float,
  Int32,
);
typedef _AcSynthesizeDart = int Function(
  Pointer<Void>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  double,
  double,
  int,
);

typedef _AcGetAudioC = Pointer<Float> Function(Pointer<Void>);
typedef _AcGetAudioDart = Pointer<Float> Function(Pointer<Void>);

typedef _AcGetAudioLengthC = Int32 Function(Pointer<Void>);
typedef _AcGetAudioLengthDart = int Function(Pointer<Void>);

typedef _AcGetSampleRateC = Int32 Function(Pointer<Void>);
typedef _AcGetSampleRateDart = int Function(Pointer<Void>);

typedef _AcGetErrorC = Pointer<Utf8> Function(Pointer<Void>);
typedef _AcGetErrorDart = Pointer<Utf8> Function(Pointer<Void>);

/// FFI bindings to the `audiocpp_ffi` shared library (endo5501/audio.cpp
/// fork), exposing the Irodori-TTS C API described in design D3.
class AudiocppNativeBindings {
  AudiocppNativeBindings(DynamicLibrary library) : _library = library;

  factory AudiocppNativeBindings.open() {
    final library = DynamicLibrary.open(libraryName);
    return AudiocppNativeBindings(library);
  }

  final DynamicLibrary _library;

  static String get libraryName {
    if (Platform.isMacOS) return 'libaudiocpp_ffi.dylib';
    if (Platform.isWindows) return 'audiocpp_ffi.dll';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  late final createAbortHandle = _library.lookupFunction<
    _AcCreateAbortHandleC,
    _AcCreateAbortHandleDart
  >('audiocpp_create_abort_handle');

  late final freeAbortHandle = _library.lookupFunction<
    _AcFreeAbortHandleC,
    _AcFreeAbortHandleDart
  >('audiocpp_free_abort_handle');

  late final abort = _library.lookupFunction<_AcAbortC, _AcAbortDart>(
    'audiocpp_abort',
  );

  late final resetAbort =
      _library.lookupFunction<_AcResetAbortC, _AcResetAbortDart>(
    'audiocpp_reset_abort',
  );

  late final init = _library.lookupFunction<_AcInitC, _AcInitDart>(
    'audiocpp_init',
  );

  late final isLoaded =
      _library.lookupFunction<_AcIsLoadedC, _AcIsLoadedDart>(
    'audiocpp_is_loaded',
  );

  late final free = _library.lookupFunction<_AcFreeC, _AcFreeDart>(
    'audiocpp_free',
  );

  late final synthesize =
      _library.lookupFunction<_AcSynthesizeC, _AcSynthesizeDart>(
    'audiocpp_synthesize',
  );

  late final getAudio =
      _library.lookupFunction<_AcGetAudioC, _AcGetAudioDart>(
    'audiocpp_get_audio',
  );

  late final getAudioLength =
      _library.lookupFunction<_AcGetAudioLengthC, _AcGetAudioLengthDart>(
    'audiocpp_get_audio_length',
  );

  late final getSampleRate =
      _library.lookupFunction<_AcGetSampleRateC, _AcGetSampleRateDart>(
    'audiocpp_get_sample_rate',
  );

  late final getError =
      _library.lookupFunction<_AcGetErrorC, _AcGetErrorDart>(
    'audiocpp_get_error',
  );
}
