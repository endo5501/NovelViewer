import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
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

/// Encodes PCM chunks from a [Uint8List] into [mp3Builder] using LAME FFI.
/// Shared helper used by [encodeSegmentsToMp3].
void _encodePcmChunks(
  Uint8List pcmData,
  Pointer<Int16> pcmPtr,
  Pointer<Uint8> mp3Buf,
  BytesBuilder mp3Builder,
  LameEncBindings bindings,
) {
  final totalSamples = pcmData.length ~/ 2;
  var samplesProcessed = 0;

  while (samplesProcessed < totalSamples) {
    final remaining = totalSamples - samplesProcessed;
    final chunkSamples =
        remaining < _encodeChunkSize ? remaining : _encodeChunkSize;

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
  }
}

/// Encodes multiple WAV segments directly to MP3 without concatenating
/// all PCM data into a single buffer. Processes segments one by one
/// for better memory efficiency.
Future<void> encodeSegmentsToMp3({
  required List<Uint8List> wavSegments,
  required String outputPath,
  required int sampleRate,
  required int bitrate,
  LameEncBindings? bindings,
  void Function(int current, int total)? onSegmentProgress,
}) async {
  if (wavSegments.isEmpty) return;

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
      final totalSegments = wavSegments.length;
      for (var i = 0; i < totalSegments; i++) {
        final pcmData = extractPcmFromWav(wavSegments[i]);
        _encodePcmChunks(pcmData, pcmPtr, mp3Buf, mp3Builder, bindings);
        onSegmentProgress?.call(i + 1, totalSegments);
      }

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

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(mp3Builder.takeBytes());
  } finally {
    bindings.close();
  }
}

// --- Isolate worker for export with progress ---

sealed class _ExportMessage {}

class _ExportProgress extends _ExportMessage {
  _ExportProgress(this.current, this.total);
  final int current;
  final int total;
}

class _ExportDone extends _ExportMessage {}

class _ExportError extends _ExportMessage {
  _ExportError(this.message);
  final String message;
}

/// Runs the full export pipeline in a background isolate with progress
/// reporting via [onProgress]. Processes segments one by one for memory
/// efficiency.
Future<void> exportToMp3WithProgress({
  required List<Uint8List> wavSegments,
  required String outputPath,
  required int sampleRate,
  required int bitrate,
  required void Function(int current, int total) onProgress,
}) async {
  final receivePort = ReceivePort();
  final exitPort = ReceivePort();
  // Listen before spawn to avoid race if isolate exits immediately.
  exitPort.listen((_) => receivePort.close());

  await Isolate.spawn(
    _exportWorker,
    (
      sendPort: receivePort.sendPort,
      wavSegments: wavSegments,
      outputPath: outputPath,
      sampleRate: sampleRate,
      bitrate: bitrate,
    ),
    onExit: exitPort.sendPort,
  );

  String? error;
  var done = false;

  await for (final message in receivePort) {
    if (message is _ExportProgress) {
      onProgress(message.current, message.total);
    } else if (message is _ExportDone) {
      done = true;
      break;
    } else if (message is _ExportError) {
      error = message.message;
      break;
    }
  }

  receivePort.close();
  exitPort.close();

  if (error != null) {
    throw Exception(error);
  }
  if (!done) {
    throw Exception('Export isolate terminated unexpectedly');
  }
}

void _exportWorker(
  ({
    SendPort sendPort,
    List<Uint8List> wavSegments,
    String outputPath,
    int sampleRate,
    int bitrate,
  }) params,
) async {
  try {
    await encodeSegmentsToMp3(
      wavSegments: params.wavSegments,
      outputPath: params.outputPath,
      sampleRate: params.sampleRate,
      bitrate: params.bitrate,
      onSegmentProgress: (current, total) {
        params.sendPort.send(_ExportProgress(current, total));
      },
    );
    params.sendPort.send(_ExportDone());
  } catch (e) {
    params.sendPort.send(_ExportError(e.toString()));
  }
}
