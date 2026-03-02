import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/voice_recording_service.dart';
import 'package:record/record.dart';

/// Fake AudioRecorder for testing without native platform code.
class FakeAudioRecorder implements AudioRecorder {
  bool _recording = false;
  String? _outputPath;
  RecordConfig? lastConfig;
  bool permissionGranted = true;
  final _amplitudeController = StreamController<Amplitude>.broadcast();
  final _stateController = StreamController<RecordState>.broadcast();

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    lastConfig = config;
    _outputPath = path;
    _recording = true;
    // Create the file to simulate recording
    await File(path).writeAsString('fake wav data');
  }

  @override
  Future<String?> stop() async {
    _recording = false;
    return _outputPath;
  }

  @override
  Future<void> cancel() async {
    _recording = false;
    if (_outputPath != null) {
      final file = File(_outputPath!);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  @override
  Future<bool> isRecording() async => _recording;

  @override
  Future<bool> hasPermission({bool request = true}) async => permissionGranted;

  @override
  Future<Amplitude> getAmplitude() async => Amplitude(current: -20.0, max: -10.0);

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) => _amplitudeController.stream;

  @override
  Stream<RecordState> onStateChanged() => _stateController.stream;

  @override
  Future<void> dispose() async {
    await _amplitudeController.close();
    await _stateController.close();
  }

  // Unused methods - required by interface
  @override
  Future<bool> isPaused() async => false;
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async =>
      const Stream.empty();
  @override
  Future<List<InputDevice>> listInputDevices() async => [];
  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;
  @override
  List<int> convertBytesToInt16(Uint8List bytes, [Endian endian = Endian.little]) => [];
  @override
  RecordIos? get ios => null;
}

void main() {
  late Directory tempDir;
  late FakeAudioRecorder fakeRecorder;
  late VoiceRecordingService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('voice_rec_test_');
    fakeRecorder = FakeAudioRecorder();
    service = VoiceRecordingService(recorder: fakeRecorder);
  });

  tearDown(() async {
    await service.dispose();
    tempDir.deleteSync(recursive: true);
  });

  group('hasPermission', () {
    test('returns true when permission is granted', () async {
      fakeRecorder.permissionGranted = true;
      expect(await service.hasPermission(), isTrue);
    });

    test('returns false when permission is denied', () async {
      fakeRecorder.permissionGranted = false;
      expect(await service.hasPermission(), isFalse);
    });
  });

  group('startRecording', () {
    test('starts recording with WAV format, 16kHz, mono', () async {
      await service.startRecording(tempDir.path);

      expect(fakeRecorder.lastConfig, isNotNull);
      expect(fakeRecorder.lastConfig!.encoder, AudioEncoder.wav);
      expect(fakeRecorder.lastConfig!.sampleRate, 16000);
      expect(fakeRecorder.lastConfig!.numChannels, 1);
    });

    test('creates a temp file in the specified directory', () async {
      await service.startRecording(tempDir.path);

      expect(service.tempFilePath, isNotNull);
      expect(service.tempFilePath!.startsWith(tempDir.path), isTrue);
      expect(service.tempFilePath!.endsWith('.wav'), isTrue);
    });

    test('reports recording state as true after start', () async {
      await service.startRecording(tempDir.path);
      expect(await service.isRecording(), isTrue);
    });
  });

  group('stopRecording', () {
    test('returns the recorded file path', () async {
      await service.startRecording(tempDir.path);
      final path = await service.stopRecording();

      expect(path, isNotNull);
      expect(path!.endsWith('.wav'), isTrue);
      expect(File(path).existsSync(), isTrue);
    });

    test('reports recording state as false after stop', () async {
      await service.startRecording(tempDir.path);
      await service.stopRecording();
      expect(await service.isRecording(), isFalse);
    });
  });

  group('cancelRecording', () {
    test('stops recording and deletes temp file', () async {
      await service.startRecording(tempDir.path);
      final tempPath = service.tempFilePath!;

      await service.cancelRecording();

      expect(await service.isRecording(), isFalse);
      expect(File(tempPath).existsSync(), isFalse);
    });
  });
}
