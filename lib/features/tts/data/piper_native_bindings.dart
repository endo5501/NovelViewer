import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// piper_tts_init(const char* model_path, const char* dic_dir) -> piper_tts_ctx*
typedef _PInitC = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _PInitDart = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _PIsLoadedC = Int32 Function(Pointer<Void>);
typedef _PIsLoadedDart = int Function(Pointer<Void>);

typedef _PFreeC = Void Function(Pointer<Void>);
typedef _PFreeDart = void Function(Pointer<Void>);

typedef _PSynthesizeC = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef _PSynthesizeDart = int Function(Pointer<Void>, Pointer<Utf8>);

typedef _PSetFloatC = Int32 Function(Pointer<Void>, Float);
typedef _PSetFloatDart = int Function(Pointer<Void>, double);

typedef _PGetAudioC = Pointer<Float> Function(Pointer<Void>);
typedef _PGetAudioDart = Pointer<Float> Function(Pointer<Void>);

typedef _PGetIntC = Int32 Function(Pointer<Void>);
typedef _PGetIntDart = int Function(Pointer<Void>);

typedef _PGetErrorC = Pointer<Utf8> Function(Pointer<Void>);
typedef _PGetErrorDart = Pointer<Utf8> Function(Pointer<Void>);

class PiperNativeBindings {
  PiperNativeBindings(DynamicLibrary library) : _library = library;

  factory PiperNativeBindings.open() {
    final library = DynamicLibrary.open(libraryName);
    return PiperNativeBindings(library);
  }

  final DynamicLibrary _library;

  static String get libraryName {
    if (Platform.isMacOS) return 'libpiper_tts_ffi.dylib';
    if (Platform.isWindows) return 'piper_tts_ffi.dll';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  late final init = _library.lookupFunction<_PInitC, _PInitDart>(
    'piper_tts_init',
  );

  late final isLoaded = _library.lookupFunction<_PIsLoadedC, _PIsLoadedDart>(
    'piper_tts_is_loaded',
  );

  late final free = _library.lookupFunction<_PFreeC, _PFreeDart>(
    'piper_tts_free',
  );

  late final synthesize =
      _library.lookupFunction<_PSynthesizeC, _PSynthesizeDart>(
    'piper_tts_synthesize',
  );

  late final setLengthScale =
      _library.lookupFunction<_PSetFloatC, _PSetFloatDart>(
    'piper_tts_set_length_scale',
  );

  late final setNoiseScale =
      _library.lookupFunction<_PSetFloatC, _PSetFloatDart>(
    'piper_tts_set_noise_scale',
  );

  late final setNoiseW = _library.lookupFunction<_PSetFloatC, _PSetFloatDart>(
    'piper_tts_set_noise_w',
  );

  late final getAudio = _library.lookupFunction<_PGetAudioC, _PGetAudioDart>(
    'piper_tts_get_audio',
  );

  late final getAudioLength =
      _library.lookupFunction<_PGetIntC, _PGetIntDart>(
    'piper_tts_get_audio_length',
  );

  late final getSampleRate =
      _library.lookupFunction<_PGetIntC, _PGetIntDart>(
    'piper_tts_get_sample_rate',
  );

  late final getError = _library.lookupFunction<_PGetErrorC, _PGetErrorDart>(
    'piper_tts_get_error',
  );
}
