import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';

import 'irodori_audio_join.dart';
import 'irodori_sentence_splitter.dart';
import 'speech_cpp_native_bindings.dart';
import 'tts_engine.dart';

/// Thrown when a synthesis stops because an abort was asked for, so that a
/// caller can tell it apart from a failure.
class TtsSynthesisCancelledException extends TtsEngineException {
  const TtsSynthesisCancelledException() : super('Irodori synthesis cancelled');
}

/// What [SpeechCppIrodoriEngine] needs of a loaded speech.cpp model.
///
/// An interface so the engine's own rules — voices, captions, pieces, aborts
/// — are exercised without the native library.
abstract interface class SpeechCppIrodoriModel {
  int get sampleRate;

  void addVoice(String name, String path);

  /// Speaks one request of [text] with the [strings] and [ints] options, set
  /// by name, stopping once [shouldStop] answers true.
  SpeechCppSynthesis synthesize(
    String text, {
    required Map<String, String> strings,
    required Map<String, int> ints,
    required bool Function() shouldStop,
  });

  void dispose();
}

/// Irodori-TTS v4.1 Small MF on speech.cpp, the runtime Irodori-TTS has on
/// iOS (`irodori-speech-cpp-engine`).
///
/// It answers the synthesis calls audio.cpp's [IrodoriTtsEngine] answers, so
/// the worker can run either:
/// - a reference voice is added to the model once per load and reused;
/// - a caption is sent as speech.cpp's `instructions`;
/// - a sentence longer than [maxPieceLength] is spoken in pieces cut at its
///   commas, with one seed, and joined with a pause of at least
///   [minPauseSeconds];
/// - the guidance scales and the step count are taken and not used: MF folded
///   the guidance into its training, and speech.cpp refuses those options.
///
/// Aborting reads the flag at the address the worker is given
/// (`SpeechCppAbortHandle`), at each sampler step and decoded window. The
/// flag belongs to the caller and outlives this engine, so [abort] and
/// [resetAbort] stay safe after [dispose].
class SpeechCppIrodoriEngine {
  SpeechCppIrodoriEngine({
    required SpeechCppIrodoriModel Function(String ggufPath) loadModelAt,
    this.maxPieceLength = irodoriMaxPieceLength,
    this.minPauseSeconds = irodoriMinCommaPauseSeconds,
    Random? random,
  }) : _loadModelAt = loadModelAt,
       _random = random ?? Random();

  /// Loads models through the speech.cpp framework the app embeds.
  factory SpeechCppIrodoriEngine.open() {
    final bindings = SpeechCppNativeBindings.open();
    return SpeechCppIrodoriEngine(
      loadModelAt: (path) => _NativeModel(SpeechCppModel.load(bindings, path)),
    );
  }

  final SpeechCppIrodoriModel Function(String ggufPath) _loadModelAt;
  final Random _random;
  final int maxPieceLength;
  final double minPauseSeconds;

  SpeechCppIrodoriModel? _model;
  Pointer<Int32> _abortFlag = nullptr;

  /// Voice names by reference path, for the loaded model only: speech.cpp
  /// keeps a voice with the model it was added to.
  final _voices = <String, String>{};

  bool get isLoaded => _model != null;

  /// Loads the GGUF at [ggufPath], replacing any model loaded before, and
  /// reads aborts from the 32-bit flag at [abortHandleAddress] (0 for none).
  void loadModel(String ggufPath, {required int abortHandleAddress}) {
    dispose();
    _abortFlag = Pointer<Int32>.fromAddress(abortHandleAddress);
    try {
      _model = _loadModelAt(ggufPath);
    } on SpeechCppException catch (e) {
      throw TtsEngineException('Failed to load Irodori-TTS model: $e');
    }
  }

  TtsSynthesisResult synthesize(
    String text, {
    String? refWavPath,
    String? caption,
    required double speakerGuidanceScale,
    required double captionGuidanceScale,
    required int numInferenceSteps,
  }) {
    final model = _model;
    if (model == null) {
      throw const TtsEngineException('Irodori-TTS model not loaded');
    }

    final strings = {
      'voice': refWavPath == null || refWavPath.isEmpty
          ? 'none'
          : _voiceFor(model, refWavPath),
      if (caption != null && caption.isNotEmpty) 'instructions': caption,
    };
    // One seed for every piece, so the pieces of a sentence come from the
    // same draw. speech.cpp takes 0 to 2^53 - 1.
    final ints = {'seed': _random.nextInt(1 << 32)};

    final pieces = <Float32List>[];
    for (final piece in splitAtCommas(text, maxLength: maxPieceLength)) {
      if (_abortRequested()) throw const TtsSynthesisCancelledException();
      final SpeechCppSynthesis outcome;
      try {
        outcome = model.synthesize(
          piece,
          strings: strings,
          ints: ints,
          shouldStop: _abortRequested,
        );
      } on SpeechCppException catch (e) {
        throw TtsEngineException('Irodori synthesis failed for "$piece": $e');
      }
      switch (outcome) {
        case SpeechCppAudio(:final samples):
          pieces.add(samples);
        case SpeechCppCancelled():
          throw const TtsSynthesisCancelledException();
      }
    }
    if (pieces.isEmpty || pieces.every((p) => p.isEmpty)) {
      throw const TtsEngineException('No audio data generated');
    }
    return TtsSynthesisResult(
      audio: joinWithPause(
        pieces,
        sampleRate: model.sampleRate,
        minPauseSeconds: minPauseSeconds,
      ),
      sampleRate: model.sampleRate,
    );
  }

  String _voiceFor(SpeechCppIrodoriModel model, String path) {
    final known = _voices[path];
    if (known != null) return known;
    final name = 'ref${_voices.length}';
    try {
      model.addVoice(name, path);
    } on SpeechCppException catch (e) {
      throw TtsEngineException('Irodori reference voice "$path" failed: $e');
    }
    _voices[path] = name;
    return name;
  }

  bool _abortRequested() => _abortFlag != nullptr && _abortFlag.value != 0;

  /// Sets the abort flag. The worker isolate rarely calls this itself; the
  /// main isolate writes the same flag through its handle.
  void abort() {
    if (_abortFlag != nullptr) _abortFlag.value = 1;
  }

  /// Clears the abort flag so the next synthesis runs.
  void resetAbort() {
    if (_abortFlag != nullptr) _abortFlag.value = 0;
  }

  /// Frees the model. The abort flag is the caller's and is left alone.
  void dispose() {
    _model?.dispose();
    _model = null;
    _voices.clear();
  }
}

class _NativeModel implements SpeechCppIrodoriModel {
  _NativeModel(this._model);

  final SpeechCppModel _model;

  @override
  int get sampleRate => _model.sampleRate;

  @override
  void addVoice(String name, String path) => _model.addVoice(name, path);

  @override
  SpeechCppSynthesis synthesize(
    String text, {
    required Map<String, String> strings,
    required Map<String, int> ints,
    required bool Function() shouldStop,
  }) {
    final request = _model.newRequest(text, strings: strings, ints: ints);
    try {
      return request.synthesize(shouldStop: shouldStop);
    } finally {
      request.dispose();
    }
  }

  @override
  void dispose() => _model.dispose();
}
