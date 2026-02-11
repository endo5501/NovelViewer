import 'dart:io';

import 'package:path_provider/path_provider.dart';

class NovelLibraryService {
  final String? _basePath;

  NovelLibraryService({String? basePath}) : _basePath = basePath;

  static const _libraryDirName = 'NovelViewer';

  String get libraryPath {
    if (_basePath != null) {
      return '$_basePath/$_libraryDirName';
    }
    throw StateError('basePath not set. Use resolveLibraryPath() first.');
  }

  Future<String> resolveLibraryPath() async {
    if (_basePath != null) {
      return '$_basePath/$_libraryDirName';
    }
    final documentsDir = await getApplicationDocumentsDirectory();
    return '${documentsDir.path}/$_libraryDirName';
  }

  Future<Directory> ensureLibraryDirectory() async {
    final path = await resolveLibraryPath();
    final dir = Directory(path);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
