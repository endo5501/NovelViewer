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

  const DirectoryEntry({required this.name, required this.path});
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
    final numbered = <FileEntry>[];
    final nonNumbered = <FileEntry>[];

    for (final file in files) {
      final match = RegExp(r'^(\d+)').firstMatch(file.name);
      if (match != null) {
        numbered.add(file);
      } else {
        nonNumbered.add(file);
      }
    }

    numbered.sort((a, b) {
      final numA = int.parse(RegExp(r'^(\d+)').firstMatch(a.name)!.group(1)!);
      final numB = int.parse(RegExp(r'^(\d+)').firstMatch(b.name)!.group(1)!);
      return numA.compareTo(numB);
    });

    nonNumbered.sort((a, b) => a.name.compareTo(b.name));

    return [...numbered, ...nonNumbered];
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
