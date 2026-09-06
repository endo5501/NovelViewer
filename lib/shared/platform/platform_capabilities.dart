/// Which optional features the running platform supports.
///
/// The app targets desktop (macOS/Windows/Linux) and iPad. Everything the
/// reader itself needs works on both; the features named here each depend on
/// something the iPad build does not have, and would fail — or lead nowhere —
/// if their controls were shown there.
///
/// Features are named individually even though today they are unavailable
/// together, so that a call site reads as the reason it hides a surface. A bare
/// `!Platform.isIOS` at the point of use says nothing about what it protects.
///
/// This model knows nothing about `dart:io`: it is derived from platform flags
/// by [PlatformCapabilities.forPlatform], so it can be evaluated in a unit test
/// for a platform the test is not running on. The single `Platform` read lives
/// in the provider that wraps it.
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.textToSpeech,
    required this.appUpdate,
    required this.llmSummary,
  });

  /// The one mapping from a platform to the features it supports.
  ///
  /// iOS has no TTS native library, no microphone usage description, and no
  /// registration for the drag-and-drop plugin the voice-reference UI uses; it
  /// has no distribution channel the app could update itself through; and its
  /// transport policy blocks the plaintext HTTP endpoint an LLM server is
  /// reached at by default.
  const PlatformCapabilities.forPlatform({required bool isIOS})
    : textToSpeech = !isIOS,
      appUpdate = !isIOS,
      llmSummary = !isIOS;

  /// Speech synthesis, its settings, and the reading dictionary that feeds it.
  final bool textToSpeech;

  /// Checking for, and applying, a newer release of the app itself.
  final bool appUpdate;

  /// Summarizing a selected word through an external LLM server.
  final bool llmSummary;
}
