/// Which optional features the running platform supports.
///
/// The app targets desktop (macOS/Windows/Linux) and iPad. Everything the
/// reader itself needs works on both; the features named here each depend on
/// something a platform may not have, and would fail — or lead nowhere — if
/// their controls were shown where it is missing.
///
/// Features are named individually so that a call site reads as the reason it
/// hides a surface. A bare `!Platform.isIOS` at the point of use says nothing
/// about what it protects, and it also ties features together that have no
/// reason to move as one: LLM summary became available on iPad without the
/// other two, and folding it into a shared expression would have hidden that.
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
  /// registration for the drag-and-drop plugin the voice-reference UI uses; and
  /// it has no distribution channel the app could update itself through. Those
  /// two features are therefore withheld there.
  ///
  /// LLM summary is not, and takes no notice of [isIOS]. Its work is done by a
  /// server the reader runs themselves, reached over plain HTTP, and nothing in
  /// that path is platform-specific: requests go through `dart:io`'s
  /// `HttpClient`, which opens its own sockets rather than using the system's
  /// URL loading layer, so the transport policy that restricts plaintext HTTP
  /// never sees them. What iOS does restrict is reaching a host on the local
  /// network, which needs a usage description and the reader's permission. That
  /// bears on where the server may be, not on whether the feature exists, so it
  /// is not modelled here.
  ///
  /// This leaves a capability that is true everywhere. It is kept rather than
  /// removed for two reasons: the plaintext claim above is to be confirmed
  /// against a device before the surfaces it guards are dismantled, and an
  /// on-device model would reintroduce a real distinction, since running one
  /// depends on the hardware rather than on the platform.
  const PlatformCapabilities.forPlatform({required bool isIOS})
    : textToSpeech = !isIOS,
      appUpdate = !isIOS,
      llmSummary = true;

  /// Speech synthesis, its settings, and the reading dictionary that feeds it.
  final bool textToSpeech;

  /// Checking for, and applying, a newer release of the app itself.
  final bool appUpdate;

  /// Summarizing a selected word through an external LLM server.
  final bool llmSummary;
}
