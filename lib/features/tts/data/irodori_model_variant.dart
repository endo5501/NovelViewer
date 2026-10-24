import 'package:novel_viewer/shared/platform/platform_capabilities.dart';

/// Selectable Irodori-TTS model generation.
///
/// v4 was once offered as a caption-less alternative: measured on the v4 Small
/// release (audio.cpp `238ab6a`), it appended a short phrase that is not in the
/// input text whenever a reference voice **and** a caption were supplied
/// together — 10 out of 10 runs. The cause was the duration predictor asking
/// for more time than the text needs, and the engine's duration correction
/// bounds the length instead, so both variants take captions now.
///
/// v4.1 Small MF runs on speech.cpp, the runtime Irodori-TTS has on iOS: on an
/// iPad mini (A17 Pro, 8GB) its F16 model left at least 1,349 MiB of the app's
/// memory free, where audio.cpp's v3 f16 did not fit (speech-cpp-ios-spike,
/// 2026-10-24).
///
/// See spec `irodori-model-variant` and `irodori-duration-correction`.
enum IrodoriModelVariant {
  v3(
    storageKey: 'v3',
    label: 'v3 600M VoiceDesign',
    modelDirName: 'Irodori-TTS-600M-v3-VoiceDesign-GGUF',
    ggufFileName: 'irodori-tts-600m-v3-voicedesign-f16.gguf',
    expectedFileSize: 1463787680,
    supportsCaption: true,
    needsDurationCorrection: false,
    runtime: IrodoriRuntime.audioCpp,
    acceptsGuidance: true,
  ),
  v4(
    storageKey: 'v4',
    label: 'v4 Small',
    modelDirName: 'Irodori-TTS-v4-Small-GGUF',
    ggufFileName: 'irodori-tts-v4-small-f16.gguf',
    expectedFileSize: 1762161536,
    supportsCaption: true,
    needsDurationCorrection: true,
    runtime: IrodoriRuntime.audioCpp,
    acceptsGuidance: true,
  ),
  v41Mf(
    storageKey: 'v4.1-mf',
    label: 'v4.1 Small MF',
    modelDirName: 'Irodori-TTS-v4.1-Small-MF-GGUF',
    // F16 rather than a smaller type: in the listening check on the iPad, Q8_0
    // slurred some words and Q4_K broke up (speech-cpp-ios-spike).
    ggufFileName: 'Irodori-TTS-866M-MF-v4.1-F16.gguf',
    expectedFileSize: 1920321792,
    supportsCaption: true,
    needsDurationCorrection: false,
    runtime: IrodoriRuntime.speechCpp,
    acceptsGuidance: false,
    sourceUrl:
        'https://huggingface.co/sakasegawa/Irodori-TTS-v4.1-Small-MF-GGUF/'
        'resolve/9db7da1bec3d1069ef8e29732e0497be60c7b047',
    sha256: 'e237dc3eefe469b8bba87872beacf12fb7fe00dbdf85767edca8ec04ab910d13',
  );

  const IrodoriModelVariant({
    required this.storageKey,
    required this.label,
    required this.modelDirName,
    required this.ggufFileName,
    required this.expectedFileSize,
    required this.supportsCaption,
    required this.needsDurationCorrection,
    required this.runtime,
    required this.acceptsGuidance,
    this.sourceUrl,
    this.sha256,
  });

  /// Where the audio.cpp GGUFs are mirrored, each under its [modelDirName].
  static const _audioCppMirrorUrl =
      'https://huggingface.co/endo5501/audio.cpp/resolve/main';

  /// Value persisted in SharedPreferences. Stable across releases.
  final String storageKey;

  /// Human-readable name for the settings UI.
  final String label;

  /// Directory (under the models root) holding this variant's single GGUF.
  ///
  /// The native loader refuses to start when a model directory contains more
  /// than one `.gguf`, so each variant gets its own directory and the
  /// download service must not leave a stray file behind.
  final String modelDirName;

  /// The single GGUF file for this variant.
  ///
  /// f16, never q8_0: ggml's Vulkan backend saturates its output to a constant
  /// full scale with q8_0 weights, and Vulkan is the production Windows
  /// backend (design D7).
  final String ggufFileName;

  /// Exact byte size pinned for [ggufFileName].
  ///
  /// Trusting a hardcoded, independently-known-good size lets a
  /// corrupt-but-complete transfer be rejected instead of self-certifying as
  /// valid (memory: project-piper-model-runner-mismatch).
  final int expectedFileSize;

  /// Whether a caption may be sent to this variant's engine.
  ///
  /// Both variants accept one today. The flag stays so a future variant that
  /// cannot take a caption is excluded by changing this table rather than the
  /// synthesis call sites.
  final bool supportsCaption;

  /// Whether captioned synthesis needs the engine's duration correction.
  ///
  /// The correction bounds the generated length to roughly what the text
  /// needs, using a character rule calibrated on v4 (0.207 s per spoken
  /// codepoint, fitted on three measurements). v4 needs it: without it a
  /// reference voice and a caption together make it append a phrase that is
  /// not in the text.
  ///
  /// v3 does not. It never showed the artifact, and its captioned output ends
  /// only ~0.12 s inside what the character rule would allow, so applying a
  /// bound calibrated elsewhere could cut speech that is correct today.
  final bool needsDurationCorrection;

  /// The native runtime this variant's GGUF is read by.
  final IrodoriRuntime runtime;

  /// Whether synthesis on this variant takes the speaker and caption guidance
  /// scales and the step count.
  ///
  /// v4.1 Small MF does not: MeanFlow folded the guidance into its training,
  /// and speech.cpp refuses those options for it.
  final bool acceptsGuidance;

  /// The pinned folder [ggufFileName] is fetched from, or null for the
  /// audio.cpp mirror, where the file sits under its [modelDirName].
  final String? sourceUrl;

  /// SHA-256 of [ggufFileName], checked once a download completes. Null where
  /// only the size is pinned.
  final String? sha256;

  /// The reference-voice extensions this variant's runtime reads, in lower
  /// case. speech.cpp reads WAVE files and nothing else.
  Set<String> get referenceExtensions => switch (runtime) {
    IrodoriRuntime.audioCpp => const {'.wav', '.mp3'},
    IrodoriRuntime.speechCpp => const {'.wav'},
  };

  /// The URL the GGUF is downloaded from.
  String get downloadUrl => sourceUrl == null
      ? '$_audioCppMirrorUrl/$relativeGgufPath'
      : '$sourceUrl/$ggufFileName';

  /// POSIX-style path of the GGUF relative to the models root.
  String get relativeGgufPath => '$modelDirName/$ggufFileName';

  /// Resolves a persisted [storageKey] back to a variant.
  ///
  /// Falls back to [IrodoriModelVariant.v3] for null, empty, or unrecognised
  /// values, so an unreadable preference lands on the longer-established
  /// variant rather than switching the user's voice generation under them.
  static IrodoriModelVariant fromStorageKey(String? key) {
    for (final variant in IrodoriModelVariant.values) {
      if (variant.storageKey == key) return variant;
    }
    return IrodoriModelVariant.v3;
  }
}
