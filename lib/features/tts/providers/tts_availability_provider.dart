import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';

/// Whether text-to-speech can run on this platform.
///
/// The TTS engine is a native library loaded through `DynamicLibrary.open`,
/// built and shipped only for the desktop targets. iOS has no such library,
/// no microphone usage description for the recording flow, and no
/// registration for the drag-and-drop plugin the voice-reference UI uses — so
/// every TTS surface is withheld there rather than shown in a state that would
/// fail when touched. The reading dictionary is withheld with them: its only
/// consumer is the speech engine.
///
/// The platform itself is read once, in [platformCapabilitiesProvider]; this
/// provider only names the feature. Consumers watch it so their behaviour can
/// be exercised for both outcomes in a widget test.
final ttsSupportedProvider = Provider<bool>(
  (ref) => ref.watch(platformCapabilitiesProvider).textToSpeech,
);
