import 'dart:io';
import 'package:path/path.dart' as p;

class FileEntry {
  final String name;
  final String path;

  const FileEntry({required this.name, required this.path});
}

class DirectoryEntry {
  final String name;
  final String path;
  final String displayName;

  const DirectoryEntry({
    required this.name,
    required this.path,
    String? displayName,
  }) : displayName = displayName ?? name;
}

class FileSystemService {
  Future<List<FileEntry>> listTextFiles(String directoryPath) async {
    final dir = Directory(directoryPath);
    final entities = await dir.list().toList();

    return entities
        .whereType<File>()
        .where((f) => p.extension(f.path).toLowerCase() == '.txt')
        .map((f) => FileEntry(name: p.basename(f.path), path: f.path))
        .toList();
  }

  List<FileEntry> sortByNumericPrefix(List<FileEntry> files) {
    final numericPattern = RegExp(r'^(\d+)');

    int? extractNumber(String name) {
      final match = numericPattern.firstMatch(name);
      return match != null ? int.parse(match.group(1)!) : null;
    }

    final sorted = files.toList()
      ..sort((a, b) {
        final numA = extractNumber(a.name);
        final numB = extractNumber(b.name);

        if (numA != null && numB != null) {
          return numA.compareTo(numB);
        }
        if (numA != null) return -1;
        if (numB != null) return 1;
        return a.name.compareTo(b.name);
      });

    return sorted;
  }

  Future<List<DirectoryEntry>> listSubdirectories(String directoryPath) async {
    final dir = Directory(directoryPath);
    final entities = await dir.list().toList();

    return entities
        .whereType<Directory>()
        .map((d) => DirectoryEntry(name: p.basename(d.path), path: d.path))
        .toList();
  }
}
