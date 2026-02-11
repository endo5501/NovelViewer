import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/novel_library_service.dart';

void main() {
  group('NovelLibraryService', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('novel_lib_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('getLibraryPath returns path under given base directory', () {
      final service = NovelLibraryService(basePath: tempDir.path);
      final path = service.libraryPath;

      expect(path, '${tempDir.path}/NovelViewer');
    });

    test('ensureLibraryDirectory creates directory if not exists', () async {
      final service = NovelLibraryService(basePath: tempDir.path);
      final dir = await service.ensureLibraryDirectory();

      expect(dir.existsSync(), isTrue);
      expect(dir.path, '${tempDir.path}/NovelViewer');
    });

    test('ensureLibraryDirectory succeeds if directory already exists',
        () async {
      final service = NovelLibraryService(basePath: tempDir.path);

      // Create it first
      await service.ensureLibraryDirectory();
      // Call again - should not throw
      final dir = await service.ensureLibraryDirectory();

      expect(dir.existsSync(), isTrue);
    });
  });
}
