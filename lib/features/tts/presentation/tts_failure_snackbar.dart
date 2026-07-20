import 'package:flutter/material.dart';

import '../domain/tts_failure_message.dart';

/// Shows the shared TTS-failure snackbar: a localized [headline] joined with
/// the native engine's [reason] when one exists.
///
/// Both failure surfaces (streaming playback and the edit screen) go through
/// here so the message shape and the long-read duration stay in one place.
void showTtsFailureSnackBar(
  BuildContext context, {
  required String headline,
  String? reason,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(formatTtsFailureMessage(headline, reason)),
      // Native causes run long; the default 4s is not enough to read one.
      duration: const Duration(seconds: 8),
    ),
  );
}
