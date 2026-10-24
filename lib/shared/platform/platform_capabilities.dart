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
/// How the reader signs in to Google for progress sync.
enum ProgressSyncSignIn {
  /// The browser hands the result to a server listening on a loopback
  /// address, with Google's desktop-app OAuth client.
  desktop,

  /// The system authentication session hands the result back, with Google's
  /// iOS OAuth client. An iOS app cannot keep a loopback server listening
  /// while the browser is in front.
  ios,
}

/// The native runtime Irodori-TTS runs on here.
///
/// Declared beside the capability model rather than with the Irodori variants
/// so that this model, like [ProgressSyncSignIn], depends on nothing in the
/// features. Each variant names the runtime it needs; the variants offered are
/// those whose runtime matches the platform's.
enum IrodoriRuntime {
  /// audio.cpp, the desktop build. Its v3 f16 model exceeds the memory an iPad
  /// grants an app.
  audioCpp,

  /// speech.cpp, the iOS build (speech-cpp-ios-build), whose v4.1 Small MF
  /// model fits there.
  speechCpp,
}

class PlatformCapabilities {
  const PlatformCapabilities({
    required this.piperTts,
    required this.qwen3Tts,
    required this.irodoriTts,
    required this.ttsAudioExport,
    required this.appUpdate,
    required this.llmSummary,
    required this.onDeviceLlm,
    this.progressSyncSignIn = ProgressSyncSignIn.desktop,
    this.irodoriRuntime = IrodoriRuntime.audioCpp,
    this.voiceRecording = true,
    this.voiceFileDragDrop = true,
    this.voicesFolderReveal = true,
  });

  /// The one mapping from a platform to the features it supports.
  ///
  /// Speech synthesis is answered per engine, because each runs on a native
  /// library built per platform and they do not share an answer. Piper is
  /// built and verified for iOS (piper-ios-build). Qwen3-TTS has no iOS
  /// library, so it is withheld there. Irodori-TTS is offered everywhere, on a
  /// runtime that differs by platform: audio.cpp's model exceeds the memory an
  /// iPad grants an app, and speech.cpp's v4.1 Small MF fits
  /// (speech-cpp-ios-build). MP3 export is withheld on iOS: its LAME encoder
  /// has no iOS build.
  ///
  /// The voice-reference UI is shown on iOS for Irodori-TTS, but three of its
  /// parts are not: recording, whose microphone path is verified on the
  /// desktop only; dropping files, whose plugin has no iOS build; and opening
  /// the voices folder, which iOS reaches through the Files app instead. Whether the engine library is actually in a
  /// given build is not answered here; a missing one is reported when it is
  /// first loaded.
  ///
  /// iOS also has no distribution channel the app could update itself
  /// through, so the in-app update is withheld there.
  ///
  /// LLM summary is not withheld, and takes no notice of [isIOS]. Its work is done by a
  /// server the reader runs themselves, reached over plain HTTP, and nothing in
  /// that path is platform-specific: requests go through `dart:io`'s
  /// `HttpClient`, which opens its own sockets rather than using the system's
  /// URL loading system, which is the layer the transport policy that restricts
  /// plaintext HTTP is enforced in, so it never sees them. What iOS does
  /// restrict is reaching a host on the local network, which needs a usage
  /// description and the reader's permission. That bears on where the server
  /// may be, not on whether the feature exists, so it is not modelled here.
  ///
  /// The plaintext claim has been confirmed on an iPad simulator, which fetched
  /// a model list over `http://` from a server on the host. What that does not
  /// cover is a server on the local network, since a loopback address is exempt
  /// from the restriction that needs the reader's permission.
  ///
  /// This leaves a capability that is true everywhere. It is kept rather than
  /// removed because an on-device model reintroduces a real distinction,
  /// since running one depends on the hardware rather than on the platform.
  ///
  /// [onDeviceLlm] is that distinction, and it is the reason this takes a
  /// second flag: the framework that runs the model exists on Apple's
  /// platforms and nowhere else, so macOS and Windows part company here
  /// although they agree on everything above.
  ///
  /// What it answers is only whether the platform could host the model.
  /// Whether this particular device is eligible, whether the reader has the
  /// system intelligence feature switched on, and whether the model has
  /// finished becoming ready are not here: they are answered by asking the
  /// native side, two of them change while the app is running, and folding
  /// them in would make this neither pure nor stable.
  const PlatformCapabilities.forPlatform({
    required bool isIOS,
    required bool isMacOS,
  }) : piperTts = true,
       qwen3Tts = !isIOS,
       irodoriTts = true,
       irodoriRuntime = isIOS
           ? IrodoriRuntime.speechCpp
           : IrodoriRuntime.audioCpp,
       voiceRecording = !isIOS,
       voiceFileDragDrop = !isIOS,
       voicesFolderReveal = !isIOS,
       ttsAudioExport = !isIOS,
       appUpdate = !isIOS,
       llmSummary = true,
       onDeviceLlm = isIOS || isMacOS,
       progressSyncSignIn = isIOS
           ? ProgressSyncSignIn.ios
           : ProgressSyncSignIn.desktop;

  /// Speech synthesis, its settings, and the reading dictionary that feeds it:
  /// available wherever at least one engine is.
  bool get textToSpeech => piperTts || qwen3Tts || irodoriTts;

  /// Speech synthesis with the Piper engine.
  final bool piperTts;

  /// Speech synthesis with the Qwen3-TTS engine.
  final bool qwen3Tts;

  /// Speech synthesis with the Irodori-TTS engine.
  final bool irodoriTts;

  /// The runtime Irodori-TTS runs on here, which decides the model variants
  /// that can be offered.
  final IrodoriRuntime irodoriRuntime;

  /// Recording a reference voice with the microphone.
  final bool voiceRecording;

  /// Adding reference voices by dropping files onto the selector.
  final bool voiceFileDragDrop;

  /// Opening the voices folder in the platform's file manager.
  final bool voicesFolderReveal;

  /// Exporting synthesized audio to an MP3 file.
  final bool ttsAudioExport;

  /// Checking for, and applying, a newer release of the app itself.
  final bool appUpdate;

  /// Summarizing a selected word through an external LLM server.
  final bool llmSummary;

  /// Whether the platform could host an on-device model at all. Says nothing
  /// about whether this device can run it today.
  final bool onDeviceLlm;

  /// How progress sync signs in here. Whether sync is offered at all also
  /// depends on the OAuth client values the build carries, which is a
  /// property of the build, not of the platform, and is decided elsewhere.
  final ProgressSyncSignIn progressSyncSignIn;
}
