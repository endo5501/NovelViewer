import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether text-to-speech can run on this platform.
///
/// The TTS engine is a native library loaded through `DynamicLibrary.open`,
/// built and shipped only for the desktop targets. iOS has no such library,
/// no microphone usage description for the recording flow, and no
/// registration for the drag-and-drop plugin the voice-reference UI uses — so
/// every TTS surface is withheld there rather than shown in a state that would
/// fail when touched.
///
/// This is the single place the platform is read. Consumers watch the provider
/// so their behaviour can be exercised for both outcomes: `dart:io`'s
/// `Platform` cannot be overridden from a widget test, but a provider can.
///
/// The wider "which features does this platform support" question is out of
/// scope here; this provider is expected to be folded into that capability
/// model when it arrives, without its consumers changing.
final ttsSupportedProvider = Provider<bool>((ref) => !Platform.isIOS);
