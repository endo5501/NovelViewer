import 'tts_engine.dart';

/// What the TTS worker asks of an Irodori-TTS engine once its model is loaded,
/// whichever runtime it runs on: audio.cpp on the desktop, speech.cpp on iOS.
///
/// Loading stays with each engine, since the runtimes take different inputs
/// (a model directory and a thread count, or a GGUF file).
abstract interface class IrodoriSynthesisEngine {
  bool get isLoaded;

  /// Synthesizes [text] in the voice of [refWavPath], when given, described by
  /// [caption], when given. An engine whose model takes no guidance ignores
  /// the guidance scales and the step count.
  TtsSynthesisResult synthesize(
    String text, {
    String? refWavPath,
    String? caption,
    required double speakerGuidanceScale,
    required double captionGuidanceScale,
    required int numInferenceSteps,
  });

  void abort();

  void resetAbort();

  void dispose();
}
