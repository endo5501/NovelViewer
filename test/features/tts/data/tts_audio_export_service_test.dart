import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/lame_enc_bindings.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_export_service.dart';
import 'package:novel_viewer/features/tts/data/wav_writer.dart';

void main() {
  group('extractPcmFromWav', () {
    test('extracts PCM data by skipping 44-byte WAV header', () {
      // Create a WAV with known audio data
      final audio = Float32List.fromList([0.5, -0.5, 0.25, -0.25]);
      final wavBytes = WavWriter.toBytes(audio: audio, sampleRate: 24000);

      final pcm = extractPcmFromWav(wavBytes);

      // WAV is 44 bytes header + 4 samples * 2 bytes = 52 bytes total
      expect(wavBytes.length, 52);
      // PCM data should be 8 bytes (4 samples * 2 bytes/sample)
      expect(pcm.length, 8);
      // Verify PCM data matches the data portion of WAV (after header)
      expect(pcm, wavBytes.sublist(44));
    });

    test('returns empty for WAV with only header', () {
      // Create a minimal WAV with 0 samples
      final audio = Float32List(0);
      final wavBytes = WavWriter.toBytes(audio: audio, sampleRate: 24000);

      final pcm = extractPcmFromWav(wavBytes);

      expect(pcm.length, 0);
    });

    test('handles single sample correctly', () {
      final audio = Float32List.fromList([1.0]);
      final wavBytes = WavWriter.toBytes(audio: audio, sampleRate: 24000);

      final pcm = extractPcmFromWav(wavBytes);

      // 1 sample * 2 bytes = 2 bytes
      expect(pcm.length, 2);
    });
  });

  group('encodeSegmentsToMp3', () {
    test('encodes multiple WAV segments directly to MP3 file', () async {
      if (!Platform.isWindows) return;

      final dllPath =
          '${Directory.current.path}/build/windows/x64/runner/Release/lame_enc_ffi.dll';
      if (!File(dllPath).existsSync()) return;

      final library = DynamicLibrary.open(dllPath);
      final lameBindings = LameEncBindings(library);

      // Generate test audio: 1 second of 440Hz sine wave split into 3 segments
      const sampleRate = 24000;
      const duration = 1.0;
      final numSamples = (sampleRate * duration).toInt();
      final audio = Float32List(numSamples);
      for (var i = 0; i < numSamples; i++) {
        audio[i] =
            (0.5 * _sin(2 * 3.14159265358979 * 440 * i / sampleRate));
      }

      final third = numSamples ~/ 3;
      final wav1 = WavWriter.toBytes(
        audio: audio.sublist(0, third),
        sampleRate: sampleRate,
      );
      final wav2 = WavWriter.toBytes(
        audio: audio.sublist(third, third * 2),
        sampleRate: sampleRate,
      );
      final wav3 = WavWriter.toBytes(
        audio: audio.sublist(third * 2),
        sampleRate: sampleRate,
      );

      final outputPath =
          '${Directory.systemTemp.path}/test_segments_${DateTime.now().millisecondsSinceEpoch}.mp3';

      try {
        final progressUpdates = <(int, int)>[];
        await encodeSegmentsToMp3(
          wavSegments: [wav1, wav2, wav3],
          outputPath: outputPath,
          sampleRate: sampleRate,
          bitrate: 128,
          bindings: lameBindings,
          onSegmentProgress: (current, total) {
            progressUpdates.add((current, total));
          },
        );

        // Verify progress was reported for each segment
        expect(progressUpdates.length, 3);
        expect(progressUpdates[0], (1, 3));
        expect(progressUpdates[1], (2, 3));
        expect(progressUpdates[2], (3, 3));

        // Verify the file exists and has content
        final file = File(outputPath);
        expect(file.existsSync(), isTrue);

        final fileBytes = await file.readAsBytes();
        expect(fileBytes.length, greaterThan(0));

        // Verify MP3 header
        expect(fileBytes[0], 0xFF);
      } finally {
        final file = File(outputPath);
        if (file.existsSync()) {
          await file.delete();
        }
      }
    });

    test('handles single segment', () async {
      if (!Platform.isWindows) return;

      final dllPath =
          '${Directory.current.path}/build/windows/x64/runner/Release/lame_enc_ffi.dll';
      if (!File(dllPath).existsSync()) return;

      final library = DynamicLibrary.open(dllPath);
      final lameBindings = LameEncBindings(library);

      const sampleRate = 24000;
      final audio = Float32List.fromList(
          List.generate(2400, (i) => 0.5 * _sin(2 * 3.14159265358979 * 440 * i / sampleRate)));
      final wav = WavWriter.toBytes(audio: audio, sampleRate: sampleRate);

      final outputPath =
          '${Directory.systemTemp.path}/test_single_seg_${DateTime.now().millisecondsSinceEpoch}.mp3';

      try {
        final progressUpdates = <(int, int)>[];
        await encodeSegmentsToMp3(
          wavSegments: [wav],
          outputPath: outputPath,
          sampleRate: sampleRate,
          bitrate: 128,
          bindings: lameBindings,
          onSegmentProgress: (current, total) {
            progressUpdates.add((current, total));
          },
        );

        expect(progressUpdates.length, 1);
        expect(progressUpdates[0], (1, 1));

        final file = File(outputPath);
        expect(file.existsSync(), isTrue);
        expect(await file.length(), greaterThan(0));
      } finally {
        final file = File(outputPath);
        if (file.existsSync()) {
          await file.delete();
        }
      }
    });
  });
}

double _sin(double x) {
  // Simple sin approximation for test purposes
  x = x % (2 * 3.14159265358979);
  if (x > 3.14159265358979) x -= 2 * 3.14159265358979;
  // Taylor series approximation
  final x3 = x * x * x;
  final x5 = x3 * x * x;
  final x7 = x5 * x * x;
  return x - x3 / 6 + x5 / 120 - x7 / 5040;
}
