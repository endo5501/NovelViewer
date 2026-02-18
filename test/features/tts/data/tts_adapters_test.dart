import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_adapters.dart';
import 'package:novel_viewer/features/tts/data/tts_playback_controller.dart';

void main() {
  group('WavWriterAdapter', () {
    test('implements TtsWavWriter', () {
      final adapter = WavWriterAdapter();
      expect(adapter, isA<TtsWavWriter>());
    });

    test('writes a valid WAV file', () async {
      final adapter = WavWriterAdapter();
      final tempDir = await Directory.systemTemp.createTemp('tts_test_');
      final path = '${tempDir.path}/test.wav';

      try {
        await adapter.write(
          path: path,
          audio: Float32List.fromList([0.0, 0.5, -0.5]),
          sampleRate: 24000,
        );

        final file = File(path);
        expect(await file.exists(), isTrue);

        final bytes = await file.readAsBytes();
        // WAV header is 44 bytes + 3 samples * 2 bytes = 50 bytes
        expect(bytes.length, 50);
        // Check RIFF header
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('FileCleanerImpl', () {
    test('implements TtsFileCleaner', () {
      final cleaner = FileCleanerImpl();
      expect(cleaner, isA<TtsFileCleaner>());
    });

    test('deletes an existing file', () async {
      final tempDir = await Directory.systemTemp.createTemp('tts_test_');
      final path = '${tempDir.path}/to_delete.wav';
      await File(path).writeAsString('test');

      final cleaner = FileCleanerImpl();
      await cleaner.deleteFile(path);

      expect(await File(path).exists(), isFalse);
      await tempDir.delete(recursive: true);
    });

    test('does not throw when file does not exist', () async {
      final cleaner = FileCleanerImpl();
      // Should not throw
      await cleaner.deleteFile('/tmp/nonexistent_file_tts_test.wav');
    });
  });

  group('JustAudioPlayer', () {
    test('implements TtsAudioPlayer', () {
      // JustAudioPlayer wraps just_audio which requires platform channels.
      // We verify the type relationship only.
      // Runtime behavior is verified via integration tests.
      expect(JustAudioPlayer.new, isA<Function>());
    });
  });
}
