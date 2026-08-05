/// Selectable Irodori-TTS model generation.
///
/// v4 is not a drop-in replacement for v3. Measured on the v4 Small release
/// (audio.cpp `238ab6a`), v4 appends a short phrase that is not in the input
/// text whenever a reference voice **and** a caption are supplied together —
/// 10 out of 10 runs, while reference-only, caption-only and no-reference are
/// all clean. This app's main path is reference x caption, so v4 is offered
/// as a caption-less alternative rather than as an upgrade.
///
/// See spec `irodori-model-variant` and design D7.
enum IrodoriModelVariant {
  v3(
    storageKey: 'v3',
    label: 'v3 600M VoiceDesign',
    modelDirName: 'Irodori-TTS-600M-v3-VoiceDesign-GGUF',
    ggufFileName: 'irodori-tts-600m-v3-voicedesign-f16.gguf',
    expectedFileSize: 1463787680,
    supportsCaption: true,
  ),
  v4(
    storageKey: 'v4',
    label: 'v4 Small',
    modelDirName: 'Irodori-TTS-v4-Small-GGUF',
    ggufFileName: 'irodori-tts-v4-small-f16.gguf',
    expectedFileSize: 1762161536,
    supportsCaption: false,
  );

  const IrodoriModelVariant({
    required this.storageKey,
    required this.label,
    required this.modelDirName,
    required this.ggufFileName,
    required this.expectedFileSize,
    required this.supportsCaption,
  });

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
  final bool supportsCaption;

  /// POSIX-style path of the GGUF relative to the models root.
  String get relativeGgufPath => '$modelDirName/$ggufFileName';

  /// Resolves a persisted [storageKey] back to a variant.
  ///
  /// Falls back to [IrodoriModelVariant.v3] for null, empty, or unrecognised
  /// values so an unreadable preference never silently moves a user onto the
  /// caption-less variant.
  static IrodoriModelVariant fromStorageKey(String? key) {
    for (final variant in IrodoriModelVariant.values) {
      if (variant.storageKey == key) return variant;
    }
    return IrodoriModelVariant.v3;
  }
}
