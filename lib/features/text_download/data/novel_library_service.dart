import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NovelLibraryService {
  final String? _basePath;

  NovelLibraryService({String? basePath}) : _basePath = basePath;

  static const _libraryDirName = 'NovelViewer';
  static const _oldBundleId = 'com.example.novelViewer';
  static const _newBundleId = 'com.endo5501.novelViewer';

  String get libraryPath {
    final basePath = _basePath;
    if (basePath == null) {
      throw StateError('basePath not set. Use resolveLibraryPath() first.');
    }
    return p.join(basePath, _libraryDirName);
  }

  Future<String> resolveLibraryPath() async {
    final basePath = _basePath;
    if (basePath != null) {
      return p.join(basePath, _libraryDirName);
    }
    final documentsDir = await getApplicationDocumentsDirectory();
    return p.join(documentsDir.path, _libraryDirName);
  }

  Future<Directory> ensureLibraryDirectory() async {
    final path = await resolveLibraryPath();
    final dir = Directory(path);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> migrateFromOldBundleId() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final currentPath = documentsDir.path;

    if (!currentPath.contains(_newBundleId)) return;

    final oldPath =
        currentPath.replaceFirst(_newBundleId, _oldBundleId);
    final oldLibraryDir = Directory('$oldPath/$_libraryDirName');

    if (!oldLibraryDir.existsSync()) return;

    final newLibraryDir = Directory('$currentPath/$_libraryDirName');
    await newLibraryDir.create(recursive: true);

    try {
      await _copyDirectory(oldLibraryDir, newLibraryDir);
    } catch (_) {
      // Migration failure is non-fatal; user can manually copy files
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await for (final entity in source.list()) {
      final newPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        final targetFile = File(newPath);
        if (!targetFile.existsSync()) {
          await entity.copy(newPath);
        }
      } else if (entity is Directory) {
        final newDir = Directory(newPath);
        await newDir.create(recursive: true);
        await _copyDirectory(entity, newDir);
      }
    }
  }
}
