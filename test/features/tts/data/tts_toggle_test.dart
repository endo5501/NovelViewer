import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_toggle.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';

void main() {
  group('resolveTtsToggle', () {
    test('starts when stopped, regardless of audio state', () {
      for (final audio in TtsAudioState.values) {
        expect(
          resolveTtsToggle(audio, TtsPlaybackState.stopped),
          TtsToggleResolution.start,
          reason: 'audio=$audio',
        );
      }
    });

    test('pauses when playing', () {
      expect(
        resolveTtsToggle(TtsAudioState.ready, TtsPlaybackState.playing),
        TtsToggleResolution.pause,
      );
    });

    test('pauses when waiting', () {
      expect(
        resolveTtsToggle(TtsAudioState.generating, TtsPlaybackState.waiting),
        TtsToggleResolution.pause,
      );
    });

    test('resumes when paused', () {
      expect(
        resolveTtsToggle(TtsAudioState.ready, TtsPlaybackState.paused),
        TtsToggleResolution.resume,
      );
    });

    test('resolves to a value for every state combination', () {
      for (final audio in TtsAudioState.values) {
        for (final playback in TtsPlaybackState.values) {
          // No combination is left unresolved (stop is Escape-only, hence not
          // part of the toggle resolution at all).
          expect(resolveTtsToggle(audio, playback), isA<TtsToggleResolution>());
        }
      }
    });
  });
}
