/// Builds the message shown when TTS generation fails.
///
/// [headline] is localized; [reason] is whatever the native engine reported
/// and stays in English, because it is generated at runtime and cannot be
/// keyed for translation. A headline on its own says nothing actionable — it
/// cannot distinguish "this reference audio is unreadable" from "the model is
/// missing" — so the cause is appended whenever the engine gave one.
String formatTtsFailureMessage(String headline, String? reason) {
  final trimmed = reason?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return headline;
  }
  return '$headline: $trimmed';
}
