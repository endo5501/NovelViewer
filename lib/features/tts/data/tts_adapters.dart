import 'package:just_audio/just_audio.dart' as just_audio;

import 'tts_playback_controller.dart';

/// Concrete [TtsAudioPlayer] that wraps [just_audio.AudioPlayer].
class JustAudioPlayer implements TtsAudioPlayer {
  final _player = just_audio.AudioPlayer();

  @override
  Stream<TtsPlayerState> get playerStateStream =>
      _player.playerStateStream.map(_mapState);

  TtsPlayerState _mapState(just_audio.PlayerState state) {
    if (state.processingState == just_audio.ProcessingState.completed) {
      return TtsPlayerState.completed;
    }
    if (state.playing) {
      return TtsPlayerState.playing;
    }
    return TtsPlayerState.stopped;
  }

  @override
  Future<void> setFilePath(String path) => _player.setFilePath(path);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
