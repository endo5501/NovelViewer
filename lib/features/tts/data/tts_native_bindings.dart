import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _QTtsInitC = Pointer<Void> Function(Pointer<Utf8>, Int32);
typedef _QTtsInitDart = Pointer<Void> Function(Pointer<Utf8>, int);

typedef _QTtsIsLoadedC = Int32 Function(Pointer<Void>);
typedef _QTtsIsLoadedDart = int Function(Pointer<Void>);

typedef _QTtsFreeC = Void Function(Pointer<Void>);
typedef _QTtsFreeDart = void Function(Pointer<Void>);

typedef _QTtsSynthesizeC = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef _QTtsSynthesizeDart = int Function(Pointer<Void>, Pointer<Utf8>);

typedef _QTtsSynthesizeWithVoiceC = Int32 Function(
  Pointer<Void>,
  Pointer<Utf8>,
  Pointer<Utf8>,
);
typedef _QTtsSynthesizeWithVoiceDart = int Function(
  Pointer<Void>,
  Pointer<Utf8>,
  Pointer<Utf8>,
);

typedef _QTtsGetAudioC = Pointer<Float> Function(Pointer<Void>);
typedef _QTtsGetAudioDart = Pointer<Float> Function(Pointer<Void>);

typedef _QTtsGetAudioLengthC = Int32 Function(Pointer<Void>);
typedef _QTtsGetAudioLengthDart = int Function(Pointer<Void>);

typedef _QTtsGetSampleRateC = Int32 Function(Pointer<Void>);
typedef _QTtsGetSampleRateDart = int Function(Pointer<Void>);

typedef _QTtsGetErrorC = Pointer<Utf8> Function(Pointer<Void>);
typedef _QTtsGetErrorDart = Pointer<Utf8> Function(Pointer<Void>);

class TtsNativeBindings {
  TtsNativeBindings(DynamicLibrary library) : _library = library;

  factory TtsNativeBindings.open() {
    final library = DynamicLibrary.open(libraryName);
    return TtsNativeBindings(library);
  }

  final DynamicLibrary _library;

  static String get libraryName {
    if (Platform.isMacOS) return 'libqwen3_tts_ffi.dylib';
    if (Platform.isWindows) return 'qwen3_tts_ffi.dll';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  late final init = _library.lookupFunction<_QTtsInitC, _QTtsInitDart>(
    'qwen3_tts_init',
  );

  late final isLoaded =
      _library.lookupFunction<_QTtsIsLoadedC, _QTtsIsLoadedDart>(
    'qwen3_tts_is_loaded',
  );

  late final free = _library.lookupFunction<_QTtsFreeC, _QTtsFreeDart>(
    'qwen3_tts_free',
  );

  late final synthesize =
      _library.lookupFunction<_QTtsSynthesizeC, _QTtsSynthesizeDart>(
    'qwen3_tts_synthesize',
  );

  late final synthesizeWithVoice = _library.lookupFunction<
    _QTtsSynthesizeWithVoiceC,
    _QTtsSynthesizeWithVoiceDart
  >('qwen3_tts_synthesize_with_voice');

  late final getAudio =
      _library.lookupFunction<_QTtsGetAudioC, _QTtsGetAudioDart>(
    'qwen3_tts_get_audio',
  );

  late final getAudioLength =
      _library.lookupFunction<_QTtsGetAudioLengthC, _QTtsGetAudioLengthDart>(
    'qwen3_tts_get_audio_length',
  );

  late final getSampleRate =
      _library.lookupFunction<_QTtsGetSampleRateC, _QTtsGetSampleRateDart>(
    'qwen3_tts_get_sample_rate',
  );

  late final getError =
      _library.lookupFunction<_QTtsGetErrorC, _QTtsGetErrorDart>(
    'qwen3_tts_get_error',
  );
}
