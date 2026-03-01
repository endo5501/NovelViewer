import 'dart:ffi';
import 'dart:io';
import 'dart:isolate' show Isolate;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'lame_enc_bindings.dart';

const _wavHeaderSize = 44;
const _encodeChunkSize = 1152; // MP3 frame size
const _mp3BufSize = ((_encodeChunkSize * 5) ~/ 4) + 7200; // LAME recommended

/// Extracts raw PCM data from a WAV byte array by skipping the 44-byte header.
Uint8List extractPcmFromWav(Uint8List wavBytes) {
  if (wavBytes.length <= _wavHeaderSize) {
    return Uint8List(0);
  }
  return wavBytes.sublist(_wavHeaderSize);
}

/// Concatenates PCM data from multiple WAV segments (each with a 44-byte header).
Uint8List concatenateSegmentsPcm(List<Uint8List> wavSegments) {
  if (wavSegments.isEmpty) return Uint8List(0);

  var totalSize = 0;
  for (final segment in wavSegments) {
    final pcmSize = segment.length - _wavHeaderSize;
    if (pcmSize > 0) totalSize += pcmSize;
  }

  final result = Uint8List(totalSize);
  var offset = 0;
  for (final segment in wavSegments) {
    final pcm = extractPcmFromWav(segment);
    result.setRange(offset, offset + pcm.length, pcm);
    offset += pcm.length;
  }
  return result;
}

/// Encodes PCM data to MP3 using LAME FFI and writes to file.
Future<void> encodePcmToMp3({
  required Uint8List pcmData,
  required String outputPath,
  required int sampleRate,
  required int bitrate,
  LameEncBindings? bindings,
  void Function(int current, int total)? onProgress,
}) async {
  bindings ??= LameEncBindings.open();

  final initResult = bindings.init(sampleRate, 1, bitrate);
  if (initResult != 0) {
    throw Exception('Failed to initialize LAME encoder');
  }

  try {
    final mp3Builder = BytesBuilder(copy: false);
    final mp3Buf = calloc<Uint8>(_mp3BufSize);
    final pcmPtr = calloc<Int16>(_encodeChunkSize);

    try {
      // PCM data is int16 (2 bytes per sample)
      final totalSamples = pcmData.length ~/ 2;
      var samplesProcessed = 0;

      while (samplesProcessed < totalSamples) {
        final remaining = totalSamples - samplesProcessed;
        final chunkSamples =
            remaining < _encodeChunkSize ? remaining : _encodeChunkSize;

        // Block-copy PCM data to native memory (already little-endian int16)
        final srcOffset = pcmData.offsetInBytes + samplesProcessed * 2;
        final byteCount = chunkSamples * 2;
        final nativeBytes = pcmPtr.cast<Uint8>().asTypedList(byteCount);
        nativeBytes.setRange(
            0, byteCount, pcmData.buffer.asUint8List(srcOffset, byteCount));

        final bytesWritten =
            bindings.encode(pcmPtr, chunkSamples, mp3Buf, _mp3BufSize);
        if (bytesWritten < 0) {
          throw Exception('LAME encode error: $bytesWritten');
        }
        if (bytesWritten > 0) {
          mp3Builder.add(Uint8List.fromList(mp3Buf.asTypedList(bytesWritten)));
        }

        samplesProcessed += chunkSamples;
        onProgress?.call(samplesProcessed, totalSamples);
      }

      // Flush remaining MP3 data
      final flushBytes = bindings.flush(mp3Buf, _mp3BufSize);
      if (flushBytes < 0) {
        throw Exception('LAME flush error: $flushBytes');
      }
      if (flushBytes > 0) {
        mp3Builder.add(Uint8List.fromList(mp3Buf.asTypedList(flushBytes)));
      }
    } finally {
      calloc.free(pcmPtr);
      calloc.free(mp3Buf);
    }

    // Write to file
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(mp3Builder.takeBytes());
  } finally {
    bindings.close();
  }
}

/// Runs the full export pipeline in an isolate.
/// Concatenates WAV segments and encodes to MP3 in a background isolate.
Future<void> exportToMp3InIsolate({
  required List<Uint8List> wavSegments,
  required String outputPath,
  required int sampleRate,
  required int bitrate,
}) async {
  await Isolate.run(() async {
    final pcmData = concatenateSegmentsPcm(wavSegments);
    await encodePcmToMp3(
      pcmData: pcmData,
      outputPath: outputPath,
      sampleRate: sampleRate,
      bitrate: bitrate,
    );
  });
}
