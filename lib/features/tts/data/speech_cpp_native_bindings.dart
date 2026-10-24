import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'tts_engine.dart';

// Bindings for the part of speech.cpp's C API (include/speech.h, API 3.3) that
// the on-device measurement needs. Handles are opaque, so every one is a
// Pointer<Void>; enums are passed as Int32.

/// `SPEECH_OK`.
const speechOk = 0;

/// `SPEECH_CANCELLED`: positive, so not an error, but no audio either.
const speechCancelled = 1;

// const char * speech_version(void)
typedef _VersionC = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

// const char * speech_status_name(speech_status status)
typedef _StatusNameC = Pointer<Utf8> Function(Int32);
typedef _StatusNameDart = Pointer<Utf8> Function(int);

// const char * speech_last_error(void)
typedef _LastErrorC = Pointer<Utf8> Function();
typedef _LastErrorDart = Pointer<Utf8> Function();

// speech_status speech_option_from_name(const char * name, speech_option * option)
typedef _OptionFromNameC = Int32 Function(Pointer<Utf8>, Pointer<Int32>);
typedef _OptionFromNameDart = int Function(Pointer<Utf8>, Pointer<Int32>);

// speech_status speech_load_params_new(speech_load_params ** params)
typedef _HandleNewC = Int32 Function(Pointer<Pointer<Void>>);
typedef _HandleNewDart = int Function(Pointer<Pointer<Void>>);

// void speech_load_params_free / speech_model_free / speech_model_info_free /
// speech_request_free / speech_request_cancel (handle)
typedef _HandleVoidC = Void Function(Pointer<Void>);
typedef _HandleVoidDart = void Function(Pointer<Void>);

// speech_status speech_load_params_set_device(params, const char * device)
// speech_status speech_request_set_text(request, const char * text)
typedef _HandleStringC = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef _HandleStringDart = int Function(Pointer<Void>, Pointer<Utf8>);

// speech_status speech_load_params_set_threads(params, int threads)
typedef _HandleIntC = Int32 Function(Pointer<Void>, Int32);
typedef _HandleIntDart = int Function(Pointer<Void>, int);

// speech_status speech_model_load(const char * path,
//     const speech_load_params * params, speech_model ** model)
typedef _ModelLoadC =
    Int32 Function(Pointer<Utf8>, Pointer<Void>, Pointer<Pointer<Void>>);
typedef _ModelLoadDart =
    int Function(Pointer<Utf8>, Pointer<Void>, Pointer<Pointer<Void>>);

// speech_status speech_model_get_info(const speech_model * model,
//     speech_model_info ** info)
// speech_status speech_request_new(speech_model * model,
//     speech_request ** request)
typedef _HandleOutC = Int32 Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _HandleOutDart = int Function(Pointer<Void>, Pointer<Pointer<Void>>);

// int speech_model_info_sample_rate(const speech_model_info * info)
typedef _InfoIntC = Int32 Function(Pointer<Void>);
typedef _InfoIntDart = int Function(Pointer<Void>);

// speech_status speech_voice_add(speech_model * model, const char * name,
//     const char * path)
typedef _VoiceAddC =
    Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _VoiceAddDart =
    int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

// speech_status speech_request_set_string(request, speech_option option,
//     const char * value)
typedef _SetStringC = Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>);
typedef _SetStringDart = int Function(Pointer<Void>, int, Pointer<Utf8>);

// speech_status speech_request_set_int(request, speech_option option,
//     int64_t value)
typedef _SetIntC = Int32 Function(Pointer<Void>, Int32, Int64);
typedef _SetIntDart = int Function(Pointer<Void>, int, int);

// int (*speech_audio_callback)(const float * samples, size_t n_samples,
//     void * user_data)
typedef _AudioCallbackC = Int32 Function(Pointer<Float>, Size, Pointer<Void>);

// speech_status speech_synthesize(speech_request * request,
//     speech_audio_callback on_audio, void * user_data)
typedef _SynthesizeC =
    Int32 Function(
      Pointer<Void>,
      Pointer<NativeFunction<_AudioCallbackC>>,
      Pointer<Void>,
    );
typedef _SynthesizeDart =
    int Function(
      Pointer<Void>,
      Pointer<NativeFunction<_AudioCallbackC>>,
      Pointer<Void>,
    );

class SpeechCppNativeBindings {
  SpeechCppNativeBindings(DynamicLibrary library) : _library = library;

  factory SpeechCppNativeBindings.open() => SpeechCppNativeBindings(
    openLibrary(
      libraryNameFor(Platform.operatingSystem),
      operatingSystem: Platform.operatingSystem,
    ),
  );

  /// Opens the native library [name], or throws a [TtsEngineException] that
  /// says which library is missing and how to build it.
  ///
  /// The framework is built separately and is not tracked by Git, so a build
  /// that skipped that step is a real case, and the dynamic loader's own error
  /// names neither the step nor the script. Its text is kept after the
  /// explanation, for diagnosis.
  static DynamicLibrary openLibrary(
    String name, {
    required String operatingSystem,
  }) {
    try {
      return DynamicLibrary.open(name);
    } on ArgumentError catch (e) {
      throw TtsEngineException(
        'speech.cpp native library $name is not in this build. '
        '${buildInstructionsFor(operatingSystem)} (${e.message})',
      );
    }
  }

  /// How to produce the speech.cpp native library for [operatingSystem] (a
  /// `Platform.operatingSystem` value).
  static String buildInstructionsFor(String operatingSystem) {
    return switch (operatingSystem) {
      'ios' =>
        'Build it with scripts/build_speech_ios.sh, then rebuild the app.',
      _ => 'speech.cpp is not built for $operatingSystem.',
    };
  }

  /// The name [DynamicLibrary.open] takes on [operatingSystem] (a
  /// `Platform.operatingSystem` value).
  ///
  /// Only iOS has a build. The framework is named speech_cpp rather than
  /// upstream's libspeech so it cannot be confused with Apple's
  /// Speech.framework; it resolves against the app's
  /// `@executable_path/Frameworks` rpath.
  static String libraryNameFor(String operatingSystem) {
    return switch (operatingSystem) {
      'ios' => 'speech_cpp.framework/speech_cpp',
      _ => throw UnsupportedError(
        'speech.cpp is not built for $operatingSystem',
      ),
    };
  }

  final DynamicLibrary _library;

  late final version = _library.lookupFunction<_VersionC, _VersionDart>(
    'speech_version',
  );

  late final statusName = _library
      .lookupFunction<_StatusNameC, _StatusNameDart>('speech_status_name');

  /// The message is stored thread-locally by the library and stays valid only
  /// until the next call into it: read it right after the failing call.
  late final lastError = _library.lookupFunction<_LastErrorC, _LastErrorDart>(
    'speech_last_error',
  );

  late final optionFromName = _library
      .lookupFunction<_OptionFromNameC, _OptionFromNameDart>(
        'speech_option_from_name',
      );

  late final loadParamsNew = _library
      .lookupFunction<_HandleNewC, _HandleNewDart>('speech_load_params_new');

  late final loadParamsFree = _library
      .lookupFunction<_HandleVoidC, _HandleVoidDart>('speech_load_params_free');

  late final loadParamsSetDevice = _library
      .lookupFunction<_HandleStringC, _HandleStringDart>(
        'speech_load_params_set_device',
      );

  late final loadParamsSetThreads = _library
      .lookupFunction<_HandleIntC, _HandleIntDart>(
        'speech_load_params_set_threads',
      );

  late final modelLoad = _library.lookupFunction<_ModelLoadC, _ModelLoadDart>(
    'speech_model_load',
  );

  late final modelFree = _library.lookupFunction<_HandleVoidC, _HandleVoidDart>(
    'speech_model_free',
  );

  late final modelGetInfo = _library
      .lookupFunction<_HandleOutC, _HandleOutDart>('speech_model_get_info');

  late final modelInfoFree = _library
      .lookupFunction<_HandleVoidC, _HandleVoidDart>('speech_model_info_free');

  late final modelInfoSampleRate = _library
      .lookupFunction<_InfoIntC, _InfoIntDart>('speech_model_info_sample_rate');

  late final voiceAdd = _library.lookupFunction<_VoiceAddC, _VoiceAddDart>(
    'speech_voice_add',
  );

  late final requestNew = _library.lookupFunction<_HandleOutC, _HandleOutDart>(
    'speech_request_new',
  );

  late final requestFree = _library
      .lookupFunction<_HandleVoidC, _HandleVoidDart>('speech_request_free');

  late final requestSetText = _library
      .lookupFunction<_HandleStringC, _HandleStringDart>(
        'speech_request_set_text',
      );

  late final requestSetString = _library
      .lookupFunction<_SetStringC, _SetStringDart>('speech_request_set_string');

  late final requestSetInt = _library.lookupFunction<_SetIntC, _SetIntDart>(
    'speech_request_set_int',
  );

  /// Any thread may call it while the request exists (speech.h).
  late final requestCancel = _library
      .lookupFunction<_HandleVoidC, _HandleVoidDart>('speech_request_cancel');

  /// Blocks the calling thread, which also receives the audio callback.
  late final synthesize = _library
      .lookupFunction<_SynthesizeC, _SynthesizeDart>('speech_synthesize');
}

/// A speech.cpp call that returned an error status.
class SpeechCppException implements Exception {
  const SpeechCppException({
    required this.call,
    required this.status,
    required this.statusName,
    required this.detail,
  });

  /// The C function, or what the bindings were doing, that failed.
  final String call;

  /// The `speech_status`, negative for every error.
  final int status;

  /// The status in snake_case, or null for a value the library does not name.
  final String? statusName;

  /// `speech_last_error()` right after the failure.
  final String detail;

  @override
  String toString() =>
      'SpeechCppException: $call failed with ${statusName ?? 'status $status'}'
      ' ($status): $detail';
}

/// Turns statuses into [SpeechCppException]s.
class SpeechCppErrors {
  const SpeechCppErrors({
    required Pointer<Utf8> Function(int) statusName,
    required Pointer<Utf8> Function() lastError,
  }) : _statusName = statusName,
       _lastError = lastError;

  factory SpeechCppErrors.of(SpeechCppNativeBindings bindings) =>
      SpeechCppErrors(
        statusName: bindings.statusName,
        lastError: bindings.lastError,
      );

  final Pointer<Utf8> Function(int) _statusName;
  final Pointer<Utf8> Function() _lastError;

  /// Throws for a negative [status]. [speechOk] and [speechCancelled] return
  /// normally: whether a cancellation is a failure is the caller's to say.
  ///
  /// Call it straight after [call] returned: the message is the library's
  /// thread-local last error, which the next call into it replaces.
  void check(int status, String call) {
    if (status >= 0) return;
    final detail = _lastError();
    final name = _statusName(status);
    throw SpeechCppException(
      call: call,
      status: status,
      statusName: name == nullptr ? null : name.toDartString(),
      detail: detail == nullptr ? '' : detail.toDartString(),
    );
  }
}

/// Sets request options by name.
///
/// The ids are asked of the library each time rather than written down here:
/// `speech_option`'s numbering grows between API minors, and a stale number
/// would silently set a different option.
class SpeechCppOptions {
  const SpeechCppOptions({
    required int Function(Pointer<Utf8>, Pointer<Int32>) optionFromName,
    required int Function(Pointer<Void>, int, Pointer<Utf8>) setString,
    required int Function(Pointer<Void>, int, int) setInt,
    required SpeechCppErrors errors,
  }) : _optionFromName = optionFromName,
       _setString = setString,
       _setInt = setInt,
       _errors = errors;

  factory SpeechCppOptions.of(SpeechCppNativeBindings bindings) =>
      SpeechCppOptions(
        optionFromName: bindings.optionFromName,
        setString: bindings.requestSetString,
        setInt: bindings.requestSetInt,
        errors: SpeechCppErrors.of(bindings),
      );

  final int Function(Pointer<Utf8>, Pointer<Int32>) _optionFromName;
  final int Function(Pointer<Void>, int, Pointer<Utf8>) _setString;
  final int Function(Pointer<Void>, int, int) _setInt;
  final SpeechCppErrors _errors;

  void setString(Pointer<Void> request, String name, String value) {
    final option = _resolve(name);
    final valuePtr = value.toNativeUtf8();
    try {
      _errors.check(
        _setString(request, option, valuePtr),
        'setting option $name',
      );
    } finally {
      calloc.free(valuePtr);
    }
  }

  void setInt(Pointer<Void> request, String name, int value) {
    final option = _resolve(name);
    _errors.check(_setInt(request, option, value), 'setting option $name');
  }

  int _resolve(String name) {
    final namePtr = name.toNativeUtf8();
    final out = calloc<Int32>();
    try {
      _errors.check(_optionFromName(namePtr, out), 'resolving option $name');
      return out.value;
    } finally {
      calloc.free(namePtr);
      calloc.free(out);
    }
  }
}

/// What a synthesis ended with, when it did not fail.
sealed class SpeechCppSynthesis {
  const SpeechCppSynthesis();
}

class SpeechCppAudio extends SpeechCppSynthesis {
  const SpeechCppAudio({required this.samples, required this.sampleRate});

  final Float32List samples;
  final int sampleRate;
}

/// The request was stopped by `speech_request_cancel()`.
class SpeechCppCancelled extends SpeechCppSynthesis {
  const SpeechCppCancelled();
}

/// Maps the status `speech_synthesize()` returned to its outcome, throwing on
/// an error.
SpeechCppSynthesis synthesisOutcome(
  int status, {
  required Float32List samples,
  required int sampleRate,
  required SpeechCppErrors errors,
}) {
  errors.check(status, 'speech_synthesize');
  if (status == speechCancelled) return const SpeechCppCancelled();
  return SpeechCppAudio(samples: samples, sampleRate: sampleRate);
}

/// Joins the pieces of audio a synthesis hands to its callback.
class SampleCollector {
  final _builder = BytesBuilder(copy: true);

  /// Copies [count] samples: the native buffer is valid only during the call.
  void add(Pointer<Float> samples, int count) {
    _builder.add(samples.cast<Uint8>().asTypedList(count * 4));
  }

  /// The samples so far, leaving the collector empty for the next synthesis.
  Float32List takeSamples() {
    final bytes = _builder.takeBytes();
    return bytes.buffer.asFloat32List(bytes.offsetInBytes, bytes.length ~/ 4);
  }
}

// speech_synthesize() calls back synchronously on the thread that called it,
// so an isolate-local callback sees every piece before the call returns. One
// synthesis runs per isolate at a time, which makes one collector enough.
final _collector = SampleCollector();

int _onAudio(Pointer<Float> samples, int count, Pointer<Void> userData) {
  _collector.add(samples, count);
  return 0;
}

final _onAudioPointer = Pointer.fromFunction<_AudioCallbackC>(_onAudio, 1);

/// A loaded model. One request runs on it at a time.
class SpeechCppModel {
  SpeechCppModel._(this._bindings, this._model, this.sampleRate);

  /// Loads the GGUF at [path] on [device] ("auto", "gpu", "cpu" or a device
  /// name).
  factory SpeechCppModel.load(
    SpeechCppNativeBindings bindings,
    String path, {
    String device = 'gpu',
  }) {
    final errors = SpeechCppErrors.of(bindings);
    final paramsOut = calloc<Pointer<Void>>();
    final modelOut = calloc<Pointer<Void>>();
    final infoOut = calloc<Pointer<Void>>();
    final devicePtr = device.toNativeUtf8();
    final pathPtr = path.toNativeUtf8();
    try {
      errors.check(bindings.loadParamsNew(paramsOut), 'speech_load_params_new');
      final params = paramsOut.value;
      try {
        errors.check(
          bindings.loadParamsSetDevice(params, devicePtr),
          'speech_load_params_set_device',
        );
        errors.check(
          bindings.modelLoad(pathPtr, params, modelOut),
          'speech_model_load',
        );
      } finally {
        bindings.loadParamsFree(params);
      }
      final model = modelOut.value;
      try {
        errors.check(
          bindings.modelGetInfo(model, infoOut),
          'speech_model_get_info',
        );
      } catch (_) {
        bindings.modelFree(model);
        rethrow;
      }
      final sampleRate = bindings.modelInfoSampleRate(infoOut.value);
      bindings.modelInfoFree(infoOut.value);
      return SpeechCppModel._(bindings, model, sampleRate);
    } finally {
      calloc.free(paramsOut);
      calloc.free(modelOut);
      calloc.free(infoOut);
      calloc.free(devicePtr);
      calloc.free(pathPtr);
    }
  }

  final SpeechCppNativeBindings _bindings;
  final Pointer<Void> _model;
  final int sampleRate;

  /// Adds a voice called [name] from a voice file or a WAVE recording.
  void addVoice(String name, String path) {
    final namePtr = name.toNativeUtf8();
    final pathPtr = path.toNativeUtf8();
    try {
      SpeechCppErrors.of(
        _bindings,
      ).check(_bindings.voiceAdd(_model, namePtr, pathPtr), 'speech_voice_add');
    } finally {
      calloc.free(namePtr);
      calloc.free(pathPtr);
    }
  }

  /// A request for [text] with the string and int [options] set by name.
  SpeechCppRequest newRequest(
    String text, {
    Map<String, String> strings = const {},
    Map<String, int> ints = const {},
  }) {
    final errors = SpeechCppErrors.of(_bindings);
    final out = calloc<Pointer<Void>>();
    final Pointer<Void> request;
    try {
      errors.check(_bindings.requestNew(_model, out), 'speech_request_new');
      request = out.value;
    } finally {
      calloc.free(out);
    }
    final textPtr = text.toNativeUtf8();
    try {
      errors.check(
        _bindings.requestSetText(request, textPtr),
        'speech_request_set_text',
      );
      final options = SpeechCppOptions.of(_bindings);
      strings.forEach((name, value) => options.setString(request, name, value));
      ints.forEach((name, value) => options.setInt(request, name, value));
    } catch (_) {
      _bindings.requestFree(request);
      rethrow;
    } finally {
      calloc.free(textPtr);
    }
    return SpeechCppRequest._(_bindings, request, sampleRate);
  }

  /// Frees the model. Every request on it must have been disposed first.
  void dispose() => _bindings.modelFree(_model);
}

/// One synthesis request.
class SpeechCppRequest {
  SpeechCppRequest._(this._bindings, this._request, this._sampleRate);

  final SpeechCppNativeBindings _bindings;
  final Pointer<Void> _request;
  final int _sampleRate;

  /// The request's address, for [cancelAt] from another isolate.
  int get address => _request.address;

  /// Cancels the request at [address], from any thread, while it exists.
  static void cancelAt(SpeechCppNativeBindings bindings, int address) =>
      bindings.requestCancel(Pointer<Void>.fromAddress(address));

  /// Speaks the request, blocking this isolate until it ends.
  SpeechCppSynthesis synthesize() {
    _collector.takeSamples();
    final status = _bindings.synthesize(_request, _onAudioPointer, nullptr);
    final samples = _collector.takeSamples();
    return synthesisOutcome(
      status,
      samples: samples,
      sampleRate: _sampleRate,
      errors: SpeechCppErrors.of(_bindings),
    );
  }

  void dispose() => _bindings.requestFree(_request);
}
