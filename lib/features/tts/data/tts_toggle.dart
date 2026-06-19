import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';

/// What a single TTS toggle (Ctrl+T) should do given the current playback state.
///
/// Stop is intentionally absent: the toggle only cycles start/pause/resume;
/// stopping playback is bound to Escape instead.
enum TtsToggleResolution { start, pause, resume }

/// Resolves a TTS toggle request against the current state machine.
///
/// The decision depends only on [playback]: a [TtsAudioState] of `none`,
/// `ready`, or `generating` all start via the same streaming entry point when
/// stopped. Playing/waiting pauses; paused resumes.
TtsToggleResolution resolveTtsToggle(
  TtsAudioState audio,
  TtsPlaybackState playback,
) {
  switch (playback) {
    case TtsPlaybackState.playing:
    case TtsPlaybackState.waiting:
      return TtsToggleResolution.pause;
    case TtsPlaybackState.paused:
      return TtsToggleResolution.resume;
    case TtsPlaybackState.stopped:
      return TtsToggleResolution.start;
  }
}
