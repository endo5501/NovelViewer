/// Abstraction for audio player to enable testing.
abstract class TtsAudioPlayer {
  Stream<TtsPlayerState> get playerStateStream;
  Future<void> setFilePath(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

/// Simple player state for TTS playback.
enum TtsPlayerState { playing, paused, completed, stopped }
