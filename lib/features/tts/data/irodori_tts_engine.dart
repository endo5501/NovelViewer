import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'audiocpp_native_bindings.dart';
import 'tts_engine.dart';

/// Dart wrapper around the `audiocpp_ffi` native library, exposing the
/// Irodori-TTS-600M-v3-VoiceDesign engine (voice cloning x caption).
///
/// Mirrors the qwen3 [TtsEngine]'s abort-handle lifecycle: the handle is
/// created and owned by the caller (typically `TtsIsolate`), wired into the
/// native context at load time, and never freed here. `abort()` /
/// `resetAbort()` only ever touch the handle, so they remain safe to call
/// after [dispose] releases the synthesis context.
class IrodoriTtsEngine {
  IrodoriTtsEngine(this._bindings);

  factory IrodoriTtsEngine.open() =>
      IrodoriTtsEngine(AudiocppNativeBindings.open());

  final AudiocppNativeBindings _bindings;
  Pointer<Void> _ctx = nullptr;

  /// Abort handle wired into the native context at load time. The flag lives
  /// independently of the context, so abort/reset never dereference [_ctx].
  Pointer<Void> _abortHandle = nullptr;

  bool get isLoaded => _ctx != nullptr && _bindings.isLoaded(_ctx) != 0;

  /// Whether captioned synthesis on the loaded model asks the engine to bound
  /// the generated length. A property of the model, so it is set at load time
  /// rather than per call — see [IrodoriModelVariant.needsDurationCorrection].
  bool _durationCorrection = false;

  void loadModel(
    String modelDir, {
    int nThreads = 4,
    Pointer<Void>? abortHandle,
    bool durationCorrection = false,
  }) {
    if (_ctx != nullptr) {
      dispose();
    }

    final handle = abortHandle ?? nullptr;
    _abortHandle = handle;
    _durationCorrection = durationCorrection;
    final modelDirPtr = modelDir.toNativeUtf8();
    try {
      _ctx = _bindings.init(modelDirPtr, nThreads, handle);
    } finally {
      calloc.free(modelDirPtr);
    }

    if (_ctx == nullptr) {
      // audiocpp_init freed the failed context before returning null, so its
      // cause is unavailable via getError(ctx); fetch it from the init-error
      // buffer instead and surface it to the caller.
      final initErrorPtr = _bindings.getInitError();
      final message =
          initErrorPtr == nullptr ? '' : initErrorPtr.toDartString();
      throw TtsEngineException(
        message.isEmpty
            ? 'Failed to load Irodori-TTS model'
            : 'Failed to load Irodori-TTS model: $message',
      );
    }
  }

  /// Synthesizes [text], optionally conditioned on a reference voice
  /// ([refWavPath], voice cloning) and/or a style [caption]. Both are
  /// synthesis-time parameters; `null` or empty values are passed to the
  /// native layer as `nullptr`, selecting plain TTS / clone-only /
  /// caption-only / clone+caption per design D3.
  ///
  /// On a model loaded with `durationCorrection`, a caption additionally turns
  /// on the engine's duration correction. With a reference voice and a caption
  /// together the duration predictor asks for more time than the text needs,
  /// and the model fills the surplus with a phrase that is not in the text;
  /// the correction bounds the length instead. The two are tied together here
  /// rather than at the call sites because every caption reaches the native
  /// layer through this method, so a caller cannot send one and forget the
  /// correction.
  TtsSynthesisResult synthesize(
    String text, {
    String? refWavPath,
    String? caption,
    required double speakerGuidanceScale,
    required double captionGuidanceScale,
    required int numInferenceSteps,
  }) {
    _ensureLoaded();

    final hasCaption = caption != null && caption.isNotEmpty;
    final textPtr = text.toNativeUtf8();
    final refWavPtr = (refWavPath != null && refWavPath.isNotEmpty)
        ? refWavPath.toNativeUtf8()
        : nullptr;
    final captionPtr = hasCaption ? caption.toNativeUtf8() : nullptr;
    final options = (hasCaption && _durationCorrection)
        ? const {'duration_correction': 'true'}
        : const <String, String>{};
    final entries = options.entries.toList();
    // Without options this takes the plain entry point, which keeps every
    // caption-less path working against a native library built before
    // audiocpp_synthesize_with_options existed. The binding is looked up
    // lazily, so the newer symbol is only required once it is actually used.
    final keys =
        entries.isEmpty ? nullptr : calloc<Pointer<Utf8>>(entries.length);
    final values =
        entries.isEmpty ? nullptr : calloc<Pointer<Utf8>>(entries.length);
    for (var i = 0; i < entries.length; i++) {
      keys[i] = entries[i].key.toNativeUtf8();
      values[i] = entries[i].value.toNativeUtf8();
    }
    try {
      final result = entries.isEmpty
          ? _bindings.synthesize(
              _ctx,
              textPtr,
              refWavPtr,
              captionPtr,
              speakerGuidanceScale,
              captionGuidanceScale,
              numInferenceSteps,
            )
          : _bindings.synthesizeWithOptions(
              _ctx,
              textPtr,
              refWavPtr,
              captionPtr,
              speakerGuidanceScale,
              captionGuidanceScale,
              numInferenceSteps,
              keys,
              values,
              entries.length,
            );
      if (result != 0) {
        final error = _bindings.getError(_ctx).toDartString();
        throw TtsEngineException('Irodori synthesis failed: $error');
      }
    } finally {
      calloc.free(textPtr);
      if (refWavPtr != nullptr) calloc.free(refWavPtr);
      if (captionPtr != nullptr) calloc.free(captionPtr);
      for (var i = 0; i < entries.length; i++) {
        calloc.free(keys[i]);
        calloc.free(values[i]);
      }
      if (keys != nullptr) calloc.free(keys);
      if (values != nullptr) calloc.free(values);
    }

    return _extractAudio();
  }

  /// Signal the native engine to abort the current synthesis.
  /// Thread-safe: can be called from any isolate. Operates on the abort
  /// handle, never on the synthesis context, so it is safe across context
  /// reloads and after [dispose].
  void abort() {
    if (_abortHandle != nullptr) {
      _bindings.abort(_abortHandle);
    }
  }

  /// Clear the abort flag so subsequent synthesis calls proceed normally.
  void resetAbort() {
    if (_abortHandle != nullptr) {
      _bindings.resetAbort(_abortHandle);
    }
  }

  void dispose() {
    if (_ctx != nullptr) {
      _bindings.free(_ctx);
      _ctx = nullptr;
    }
    // The abort handle is owned by the caller (TtsIsolate); do not free it
    // here. Drop our reference so a post-dispose abort() is a no-op.
    _abortHandle = nullptr;
  }

  void _ensureLoaded() {
    if (!isLoaded) {
      throw const TtsEngineException('Irodori-TTS model not loaded');
    }
  }

  TtsSynthesisResult _extractAudio() {
    final length = _bindings.getAudioLength(_ctx);
    final sampleRate = _bindings.getSampleRate(_ctx);
    final audioPtr = _bindings.getAudio(_ctx);

    if (audioPtr == nullptr || length <= 0) {
      throw const TtsEngineException('No audio data generated');
    }

    final audio = Float32List.fromList(audioPtr.asTypedList(length));
    return TtsSynthesisResult(audio: audio, sampleRate: sampleRate);
  }
}
