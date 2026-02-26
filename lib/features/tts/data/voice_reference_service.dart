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
