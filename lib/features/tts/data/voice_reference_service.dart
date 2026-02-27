import 'dart:io';
import 'package:path/path.dart' as p;

class VoiceReferenceService {
  static const _voicesDirName = 'voices';
  static const _supportedExtensions = {'.wav', '.mp3'};

  final String libraryPath;

  VoiceReferenceService({required this.libraryPath});

  String get voicesDirPath => p.join(p.dirname(libraryPath), _voicesDirName);

  Future<void> ensureVoicesDir() async {
    final dir = Directory(voicesDirPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  Future<List<String>> listVoiceFiles() async {
    await ensureVoicesDir();
    final entities = await Directory(voicesDirPath).list().toList();
    final files = entities
        .whereType<File>()
        .where((f) => _supportedExtensions.contains(p.extension(f.path).toLowerCase()))
        .map((f) => p.basename(f.path))
        .toList();
    files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return files;
  }

  String resolveVoiceFilePath(String fileName) {
    return p.join(voicesDirPath, p.basename(fileName));
  }

  Future<String> addVoiceFile(String sourcePath) async {
    final ext = p.extension(sourcePath).toLowerCase();
    if (!_supportedExtensions.contains(ext)) {
      throw ArgumentError('Unsupported file type: $ext. Only .wav and .mp3 are supported.');
    }
    await ensureVoicesDir();
    final fileName = p.basename(sourcePath);
    final destPath = p.join(voicesDirPath, fileName);
    if (File(destPath).existsSync()) {
      throw StateError('A file named "$fileName" already exists in the voices directory.');
    }
    await File(sourcePath).copy(destPath);
    return fileName;
  }

  Future<void> renameVoiceFile(String oldName, String newName) async {
    _validateFileName(oldName);
    _validateFileName(newName);
    final oldPath = p.join(voicesDirPath, oldName);
    if (!File(oldPath).existsSync()) {
      throw StateError('File "$oldName" does not exist in the voices directory.');
    }
    final newPath = p.join(voicesDirPath, newName);
    if (File(newPath).existsSync()) {
      throw StateError('A file named "$newName" already exists in the voices directory.');
    }
    await File(oldPath).rename(newPath);
  }

  static void _validateFileName(String name) {
    if (name.isEmpty) {
      throw ArgumentError('File name is empty.');
    }
    if (p.basename(name) != name) {
      throw ArgumentError('Invalid file name: $name');
    }
  }

  Future<void> openVoicesDirectory() async {
    await ensureVoicesDir();
    final (String command, List<String> args) = switch (true) {
      _ when Platform.isMacOS => ('open', [voicesDirPath]),
      _ when Platform.isWindows => ('explorer', [voicesDirPath]),
      _ when Platform.isLinux => ('xdg-open', [voicesDirPath]),
      _ => ('', <String>[]),
    };
    if (command.isNotEmpty) {
      await Process.run(command, args);
    }
  }
}
