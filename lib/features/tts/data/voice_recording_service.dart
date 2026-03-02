import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:record/record.dart';

class VoiceRecordingService {
  final AudioRecorder recorder;
  String? _tempFilePath;

  VoiceRecordingService({required this.recorder});

  String? get tempFilePath => _tempFilePath;

  Future<bool> hasPermission() => recorder.hasPermission();

  Future<void> startRecording(String tempDirPath) async {
    final fileName =
        'recording_${DateTime.now().millisecondsSinceEpoch}.wav';
    _tempFilePath = p.join(tempDirPath, fileName);

    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
    );

    await recorder.start(config, path: _tempFilePath!);
  }

  Future<String?> stopRecording() async {
    final path = await recorder.stop();
    return path;
  }

  Future<void> cancelRecording() async {
    await recorder.cancel();
    _deleteTempFile();
  }

  Future<bool> isRecording() => recorder.isRecording();

  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      recorder.onAmplitudeChanged(interval);

  void cleanupTempFile() {
    _deleteTempFile();
  }

  Future<void> dispose() async {
    _deleteTempFile();
    await recorder.dispose();
  }

  void _deleteTempFile() {
    final path = _tempFilePath;
    if (path != null) {
      try {
        File(path).deleteSync();
      } on FileSystemException {
        // File already deleted or doesn't exist
      }
      _tempFilePath = null;
    }
  }
}
