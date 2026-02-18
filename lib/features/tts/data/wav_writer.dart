import 'dart:io';
import 'dart:typed_data';

class WavWriter {
  static Future<void> write({
    required String path,
    required Float32List audio,
    required int sampleRate,
  }) async {
    const channels = 1;
    const bitsPerSample = 16;
    const bytesPerSample = bitsPerSample ~/ 8;
    final byteRate = sampleRate * channels * bytesPerSample;
    const blockAlign = channels * bytesPerSample;
    final dataSize = audio.length * bytesPerSample;
    final fileSize = 44 + dataSize;

    final buffer = ByteData(fileSize);
    var offset = 0;

    // RIFF header
    _writeString(buffer, offset, 'RIFF');
    offset += 4;
    buffer.setUint32(offset, fileSize - 8, Endian.little);
    offset += 4;
    _writeString(buffer, offset, 'WAVE');
    offset += 4;

    // fmt chunk
    _writeString(buffer, offset, 'fmt ');
    offset += 4;
    buffer.setUint32(offset, 16, Endian.little); // chunk size
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM format
    offset += 2;
    buffer.setUint16(offset, channels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    buffer.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    buffer.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;

    // data chunk
    _writeString(buffer, offset, 'data');
    offset += 4;
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // Convert float samples to 16-bit PCM
    for (var i = 0; i < audio.length; i++) {
      final clamped = audio[i].clamp(-1.0, 1.0);
      final sample =
          clamped >= 0 ? (clamped * 32767).round() : (clamped * 32768).round();
      buffer.setInt16(offset, sample, Endian.little);
      offset += 2;
    }

    await File(path).writeAsBytes(buffer.buffer.asUint8List());
  }

  static void _writeString(ByteData buffer, int offset, String str) {
    for (var i = 0; i < str.length; i++) {
      buffer.setUint8(offset + i, str.codeUnitAt(i));
    }
  }
}
