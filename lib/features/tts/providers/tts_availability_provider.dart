import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';

/// Whether text-to-speech can run on this platform.
///
/// Each engine is a native library loaded through `DynamicLibrary.open`, built
/// per platform, so speech is available wherever at least one engine is: on
/// the desktop targets every engine, on iOS Piper and Irodori-TTS. Where none is, every
/// TTS surface is withheld rather than shown in a state that would fail when
/// touched, and the reading dictionary with them: its only consumer is the
/// speech engine.
///
/// The platform itself is read once, in [platformCapabilitiesProvider]; this
/// provider only names the feature. Consumers watch it so their behaviour can
/// be exercised for both outcomes in a widget test.
final ttsSupportedProvider = Provider<bool>(
  (ref) => ref.watch(platformCapabilitiesProvider).textToSpeech,
);

/// The engines this platform can run, in the order the engine selector lists
/// them.
///
/// On iOS this is Piper and Irodori-TTS: Qwen3-TTS has no iOS library, and
/// Irodori-TTS runs there on speech.cpp ([irodoriRuntimeProvider]). The
/// voice-reference UI comes with Irodori-TTS, without the parts iOS lacks
/// (the voice library feature providers below).
final supportedTtsEnginesProvider = Provider<List<TtsEngineType>>((ref) {
  final capabilities = ref.watch(platformCapabilitiesProvider);
  return [
    if (capabilities.qwen3Tts) TtsEngineType.qwen3,
    if (capabilities.piperTts) TtsEngineType.piper,
    if (capabilities.irodoriTts) TtsEngineType.irodori,
  ];
});

/// Whether synthesized audio can be exported to MP3 here. The LAME encoder
/// has no iOS build, so the export button is withheld there.
final ttsAudioExportSupportedProvider = Provider<bool>(
  (ref) => ref.watch(platformCapabilitiesProvider).ttsAudioExport,
);

/// The runtime Irodori-TTS runs on here, which decides the model variants
/// offered (`irodori-model-variant`).
final irodoriRuntimeProvider = Provider<IrodoriRuntime>(
  (ref) => ref.watch(platformCapabilitiesProvider).irodoriRuntime,
);

/// Whether a reference voice can be recorded with the microphone here.
final voiceRecordingSupportedProvider = Provider<bool>(
  (ref) => ref.watch(platformCapabilitiesProvider).voiceRecording,
);

/// Whether reference voices can be added by dropping files here.
final voiceFileDragDropSupportedProvider = Provider<bool>(
  (ref) => ref.watch(platformCapabilitiesProvider).voiceFileDragDrop,
);

/// Whether the voices folder can be opened in a file manager here.
final voicesFolderRevealSupportedProvider = Provider<bool>(
  (ref) => ref.watch(platformCapabilitiesProvider).voicesFolderReveal,
);
