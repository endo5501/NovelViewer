import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/voice_reference_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late VoiceReferenceService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('voice_ref_test_');
    // Create a simulated library path (like NovelViewer/)
    final libraryPath = p.join(tempDir.path, 'NovelViewer');
    Directory(libraryPath).createSync();
    service = VoiceReferenceService(libraryPath: libraryPath);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('voicesDir', () {
    test('returns voices directory path at same level as library', () {
      final expected = p.join(tempDir.path, 'voices');
      expect(service.voicesDirPath, expected);
    });
  });

  group('ensureVoicesDir', () {
    test('creates voices directory if it does not exist', () async {
      final voicesDir = Directory(service.voicesDirPath);
      expect(voicesDir.existsSync(), isFalse);

      await service.ensureVoicesDir();

      expect(voicesDir.existsSync(), isTrue);
    });

    test('succeeds if voices directory already exists', () async {
      Directory(service.voicesDirPath).createSync();

      await service.ensureVoicesDir();

      expect(Directory(service.voicesDirPath).existsSync(), isTrue);
    });
  });

  group('listVoiceFiles', () {
    test('returns supported audio files sorted alphabetically', () async {
      final voicesDir = Directory(service.voicesDirPath);
      voicesDir.createSync();
      File(p.join(voicesDir.path, 'sample_a.wav')).writeAsStringSync('');
      File(p.join(voicesDir.path, 'narrator.mp3')).writeAsStringSync('');
      File(p.join(voicesDir.path, 'readme.txt')).writeAsStringSync('');
      File(p.join(voicesDir.path, 'voice_b.wav')).writeAsStringSync('');

      final files = await service.listVoiceFiles();

      expect(files, ['narrator.mp3', 'sample_a.wav', 'voice_b.wav']);
    });

    test('returns empty list when voices directory is empty', () async {
      Directory(service.voicesDirPath).createSync();

      final files = await service.listVoiceFiles();

      expect(files, isEmpty);
    });

    test('creates directory and returns empty list when directory does not exist',
        () async {
      final files = await service.listVoiceFiles();

      expect(files, isEmpty);
      expect(Directory(service.voicesDirPath).existsSync(), isTrue);
    });

    test('ignores subdirectories', () async {
      final voicesDir = Directory(service.voicesDirPath);
      voicesDir.createSync();
      File(p.join(voicesDir.path, 'voice.wav')).writeAsStringSync('');
      Directory(p.join(voicesDir.path, 'subdir')).createSync();

      final files = await service.listVoiceFiles();

      expect(files, ['voice.wav']);
    });

    test('sorts case-insensitively', () async {
      final voicesDir = Directory(service.voicesDirPath);
      voicesDir.createSync();
      File(p.join(voicesDir.path, 'Zebra.wav')).writeAsStringSync('');
      File(p.join(voicesDir.path, 'alpha.mp3')).writeAsStringSync('');
      File(p.join(voicesDir.path, 'Beta.wav')).writeAsStringSync('');

      final files = await service.listVoiceFiles();

      expect(files, ['alpha.mp3', 'Beta.wav', 'Zebra.wav']);
    });
  });

  group('resolveVoiceFilePath', () {
    test('resolves file name to full path', () {
      final expected = p.join(service.voicesDirPath, 'narrator.mp3');
      expect(service.resolveVoiceFilePath('narrator.mp3'), expected);
    });
  });
}
