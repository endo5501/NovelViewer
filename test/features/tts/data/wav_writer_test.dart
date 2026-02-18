import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/wav_writer.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wav_writer_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('WavWriter', () {
    test('writes valid WAV file with correct RIFF header', () async {
      final audio = Float32List.fromList([0.0, 0.5, -0.5, 1.0, -1.0]);
      final path = '${tempDir.path}/test.wav';

      await WavWriter.write(path: path, audio: audio, sampleRate: 24000);

      final file = File(path);
      expect(await file.exists(), isTrue);

      final bytes = await file.readAsBytes();
      // RIFF header
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      // WAVE format
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    });

    test('writes correct format chunk for 24kHz mono 16-bit PCM', () async {
      final audio = Float32List.fromList([0.0, 0.5]);
      final path = '${tempDir.path}/test.wav';

      await WavWriter.write(path: path, audio: audio, sampleRate: 24000);

      final bytes = await File(path).readAsBytes();
      final data = ByteData.sublistView(bytes);

      // fmt chunk
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
      // PCM format (1)
      expect(data.getUint16(20, Endian.little), 1);
      // Mono (1 channel)
      expect(data.getUint16(22, Endian.little), 1);
      // Sample rate 24000
      expect(data.getUint32(24, Endian.little), 24000);
      // Byte rate = 24000 * 1 * 2 = 48000
      expect(data.getUint32(28, Endian.little), 48000);
      // Block align = 1 * 2 = 2
      expect(data.getUint16(32, Endian.little), 2);
      // Bits per sample = 16
      expect(data.getUint16(34, Endian.little), 16);
    });

    test('converts float samples to 16-bit PCM correctly', () async {
      // Test boundary values
      final audio = Float32List.fromList([0.0, 1.0, -1.0]);
      final path = '${tempDir.path}/test.wav';

      await WavWriter.write(path: path, audio: audio, sampleRate: 24000);

      final bytes = await File(path).readAsBytes();
      final data = ByteData.sublistView(bytes);

      // Data chunk starts at offset 44
      // Sample 0: 0.0 -> 0
      expect(data.getInt16(44, Endian.little), 0);
      // Sample 1: 1.0 -> 32767
      expect(data.getInt16(46, Endian.little), 32767);
      // Sample 2: -1.0 -> -32768
      expect(data.getInt16(48, Endian.little), -32768);
    });

    test('file size matches expected WAV size', () async {
      final audio = Float32List.fromList([0.1, 0.2, 0.3, 0.4, 0.5]);
      final path = '${tempDir.path}/test.wav';

      await WavWriter.write(path: path, audio: audio, sampleRate: 24000);

      final file = File(path);
      // Header (44 bytes) + data (5 samples * 2 bytes)
      expect(await file.length(), 44 + 10);
    });

    test('clamps values beyond -1.0 to 1.0 range', () async {
      final audio = Float32List.fromList([1.5, -1.5]);
      final path = '${tempDir.path}/test.wav';

      await WavWriter.write(path: path, audio: audio, sampleRate: 24000);

      final bytes = await File(path).readAsBytes();
      final data = ByteData.sublistView(bytes);

      // 1.5 clamped to 1.0 -> 32767
      expect(data.getInt16(44, Endian.little), 32767);
      // -1.5 clamped to -1.0 -> -32768
      expect(data.getInt16(46, Endian.little), -32768);
    });

    test('handles empty audio', () async {
      final audio = Float32List(0);
      final path = '${tempDir.path}/test.wav';

      await WavWriter.write(path: path, audio: audio, sampleRate: 24000);

      final file = File(path);
      expect(await file.length(), 44); // Header only
    });
  });
}
