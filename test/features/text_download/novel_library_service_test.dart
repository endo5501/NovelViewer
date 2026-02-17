import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/novel_library_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('NovelLibraryService', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('novel_lib_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('resolveLibraryPath returns path under given base directory',
        () async {
      final service = NovelLibraryService(basePath: tempDir.path);
      final path = await service.resolveLibraryPath();

      expect(path, p.join(tempDir.path, 'NovelViewer'));
    });

    test('ensureLibraryDirectory creates directory if not exists', () async {
      final service = NovelLibraryService(basePath: tempDir.path);
      final dir = await service.ensureLibraryDirectory();

      expect(dir.existsSync(), isTrue);
      expect(dir.path, p.join(tempDir.path, 'NovelViewer'));
    });

    test(
      'resolveLibraryPath returns exe-based path on Windows when no basePath',
      () async {
        final service = NovelLibraryService();
        final path = await service.resolveLibraryPath();

        final expectedBase = p.dirname(Platform.resolvedExecutable);
        expect(path, p.join(expectedBase, 'NovelViewer'));
      },
      skip: !Platform.isWindows ? 'Windows-only test' : null,
    );

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
