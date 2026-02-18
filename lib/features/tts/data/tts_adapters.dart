import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart' as just_audio;

import 'tts_playback_controller.dart';
import 'wav_writer.dart';

/// Concrete [TtsAudioPlayer] that wraps [just_audio.AudioPlayer].
class JustAudioPlayer implements TtsAudioPlayer {
  final _player = just_audio.AudioPlayer();

  @override
  Stream<TtsPlayerState> get playerStateStream =>
      _player.playerStateStream.map((state) {
        if (state.processingState == just_audio.ProcessingState.completed) {
          return TtsPlayerState.completed;
        }
        if (state.playing) {
          return TtsPlayerState.playing;
        }
        return TtsPlayerState.stopped;
      });

  @override
  Future<void> setFilePath(String path) async {
    await _player.setFilePath(path);
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }
}

/// Concrete [TtsWavWriter] that delegates to [WavWriter.write].
class WavWriterAdapter implements TtsWavWriter {
  @override
  Future<void> write({
    required String path,
    required Float32List audio,
    required int sampleRate,
  }) async {
    await WavWriter.write(path: path, audio: audio, sampleRate: sampleRate);
  }
}

/// Concrete [TtsFileCleaner] that deletes files using [dart:io].
class FileCleanerImpl implements TtsFileCleaner {
  @override
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
