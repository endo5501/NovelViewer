import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/shared/utils/file_name_utils.dart';

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

/// Categorises the ways a directory management operation can fail so the UI
/// can map each cause to a localized message.
enum DirectoryOpError {
  /// The requested name is empty or contains characters invalid for a folder.
  invalidName,

  /// A file or directory with the target name already exists.
  nameCollision,

  /// The directory is not empty and the operation only allows empty ones.
  notEmpty,

  /// A move target is the source itself or one of its descendants.
  intoSelfOrDescendant,

  /// The source path does not exist.
  sourceNotFound,

  /// An underlying filesystem operation failed (e.g. the OS held a lock on a
  /// file inside the folder, or the destination was not writable).
  ioFailure,
}

/// Raised by [FileSystemService] for directory management failures with a
/// machine-readable [error] so callers can present a tailored message.
class DirectoryOpException implements Exception {
  final DirectoryOpError error;
  final String message;

  DirectoryOpException(this.error, this.message);

  @override
  String toString() => 'DirectoryOpException($error): $message';
}

class FileSystemService {
  Future<DirectoryEntry> createDirectory(
    String parentPath,
    String name,
  ) async {
    if (!isValidFolderName(name)) {
      throw DirectoryOpException(
        DirectoryOpError.invalidName,
        'Invalid folder name: "$name"',
      );
    }
    final targetPath = p.join(parentPath, name);
    if (await FileSystemEntity.isDirectory(targetPath) ||
        await FileSystemEntity.isFile(targetPath)) {
      throw DirectoryOpException(
        DirectoryOpError.nameCollision,
        'An entry named "$name" already exists in $parentPath',
      );
    }
    try {
      await Directory(targetPath).create();
    } on FileSystemException catch (e) {
      // e.g. a Windows reserved name (CON, NUL, ...) or an unwritable parent.
      throw DirectoryOpException(
        DirectoryOpError.ioFailure,
        'Failed to create "$targetPath": ${e.message}',
      );
    }
    return DirectoryEntry(name: name, path: targetPath);
  }

  Future<DirectoryEntry> renameDirectory(
    String path_,
    String newName,
  ) async {
    if (!isValidFolderName(newName)) {
      throw DirectoryOpException(
        DirectoryOpError.invalidName,
        'Invalid folder name: "$newName"',
      );
    }
    final source = Directory(path_);
    if (!source.existsSync()) {
      throw DirectoryOpException(
        DirectoryOpError.sourceNotFound,
        'Directory not found: $path_',
      );
    }
    final targetPath = p.join(p.dirname(path_), newName);
    if (await FileSystemEntity.isDirectory(targetPath) ||
        await FileSystemEntity.isFile(targetPath)) {
      throw DirectoryOpException(
        DirectoryOpError.nameCollision,
        'An entry named "$newName" already exists',
      );
    }
    await _renameOrThrow(source, targetPath);
    return DirectoryEntry(name: newName, path: targetPath);
  }

  /// Performs the underlying [Directory.rename], translating a raw
  /// [FileSystemException] (e.g. a Windows file lock or permission error) into
  /// a [DirectoryOpException] so callers can show a localized message instead
  /// of leaking an unhandled IO error.
  Future<void> _renameOrThrow(Directory source, String targetPath) async {
    try {
      await source.rename(targetPath);
    } on FileSystemException catch (e) {
      throw DirectoryOpException(
        DirectoryOpError.ioFailure,
        'Failed to move "${source.path}" to "$targetPath": ${e.message}',
      );
    }
  }

  /// Moves [srcPath] into [destParentPath], preserving the source's leaf name
  /// (its `folder_name` for novel folders). Returns the new absolute path.
  Future<String> moveDirectory(
    String srcPath,
    String destParentPath,
  ) async {
    final source = Directory(srcPath);
    if (!source.existsSync()) {
      throw DirectoryOpException(
        DirectoryOpError.sourceNotFound,
        'Directory not found: $srcPath',
      );
    }
    if (p.equals(srcPath, destParentPath) ||
        p.isWithin(srcPath, destParentPath)) {
      throw DirectoryOpException(
        DirectoryOpError.intoSelfOrDescendant,
        'Cannot move a folder into itself or one of its descendants',
      );
    }
    final targetPath = p.join(destParentPath, p.basename(srcPath));
    if (await FileSystemEntity.isDirectory(targetPath) ||
        await FileSystemEntity.isFile(targetPath)) {
      throw DirectoryOpException(
        DirectoryOpError.nameCollision,
        'An entry named "${p.basename(srcPath)}" already exists in '
        '$destParentPath',
      );
    }
    await _renameOrThrow(source, targetPath);
    return targetPath;
  }

  /// Returns the absolute paths of every organizational folder under
  /// [libraryPath], recursively. Folders whose name is in [novelFolderNames]
  /// are treated as novel folders: they are excluded and not descended into.
  Future<List<String>> listOrganizationalFolderTree(
    String libraryPath,
    Set<String> novelFolderNames,
  ) async {
    final result = <String>[];

    Future<void> walk(String dirPath) async {
      final entities = await Directory(dirPath).list().toList();
      final subDirs = entities.whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final dir in subDirs) {
        final name = p.basename(dir.path);
        if (novelFolderNames.contains(name)) continue;
        result.add(dir.path);
        await walk(dir.path);
      }
    }

    await walk(libraryPath);
    return result;
  }

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

  Future<void> deleteDirectory(String path) async {
    final dir = Directory(path);
    await dir.delete(recursive: true);
  }

  /// Deletes [path] only when it is empty. Throws [DirectoryOpException] with
  /// [DirectoryOpError.notEmpty] when it still contains entries, and
  /// [DirectoryOpError.sourceNotFound] when it does not exist.
  Future<void> deleteEmptyDirectory(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      throw DirectoryOpException(
        DirectoryOpError.sourceNotFound,
        'Directory not found: $path',
      );
    }
    final hasEntries = await dir.list().isEmpty.then((empty) => !empty);
    if (hasEntries) {
      throw DirectoryOpException(
        DirectoryOpError.notEmpty,
        'Directory is not empty: $path',
      );
    }
    await dir.delete();
  }
}
