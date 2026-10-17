import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';

/// Whether text-to-speech can run on this platform.
///
/// Each engine is a native library loaded through `DynamicLibrary.open`, built
/// per platform, so speech is available wherever at least one engine is: on
/// the desktop targets every engine, on iOS Piper alone. Where none is, every
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
/// On iOS this is Piper alone: Qwen3-TTS has no iOS library and Irodori-TTS's
/// model does not fit in the memory an iPad grants an app. The voice-reference
/// UI, the microphone and the drag-and-drop plugin belong to those two, so
/// leaving them out of this list also keeps those off iOS.
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
