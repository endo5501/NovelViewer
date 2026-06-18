import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';

/// Tests for [FileSystemService.listDownloadDestinationFolders], which
/// enumerates organizational (non-novel) folders under the library root as
/// candidate download destinations. Novel folders and their entire subtrees
/// are pruned: a novel folder must never be offered as a destination, and
/// nothing nested inside a novel folder may be either.
void main() {
  late Directory tempDir;
  late FileSystemService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('novel_viewer_dest_');
    service = FileSystemService();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Directory mkdir(String relative) {
    final dir = Directory(p.join(tempDir.path, relative));
    dir.createSync(recursive: true);
    return dir;
  }

  group('listDownloadDestinationFolders', () {
    test('returns empty list when the library root has no subfolders',
        () async {
      final result = await service.listDownloadDestinationFolders(
        tempDir.path,
        const <String>{},
      );

      expect(result, isEmpty);
    });

    test('includes organizational folders at multiple nesting depths',
        () async {
      mkdir('完結済み');
      mkdir(p.join('完結済み', '異世界'));
      mkdir('お気に入り');

      final result = await service.listDownloadDestinationFolders(
        tempDir.path,
        const <String>{},
      );

      final names = result.map((e) => e.name).toList();
      expect(names, containsAll(['完結済み', '異世界', 'お気に入り']));
      expect(result.length, 3);
    });

    test('excludes a registered novel folder', () async {
      mkdir('完結済み');
      mkdir('narou_n1234ab');

      final result = await service.listDownloadDestinationFolders(
        tempDir.path,
        const {'narou_n1234ab'},
      );

      final names = result.map((e) => e.name).toList();
      expect(names, ['完結済み']);
    });

    test('prunes the entire subtree under a novel folder', () async {
      // A novel folder may itself contain subdirectories (e.g. future
      // per-novel asset folders). None of them may be offered as a
      // destination, because that would nest a novel inside another novel.
      mkdir(p.join('narou_n1234ab', 'assets'));
      mkdir('整理用');

      final result = await service.listDownloadDestinationFolders(
        tempDir.path,
        const {'narou_n1234ab'},
      );

      final names = result.map((e) => e.name).toList();
      expect(names, ['整理用']);
      expect(names, isNot(contains('assets')));
    });

    test(
        'includes an organizational folder that contains a novel folder, '
        'but not the novel folder itself', () async {
      mkdir('完結済み');
      mkdir(p.join('完結済み', 'kakuyomu_r000001'));

      final result = await service.listDownloadDestinationFolders(
        tempDir.path,
        const {'kakuyomu_r000001'},
      );

      final names = result.map((e) => e.name).toList();
      expect(names, ['完結済み']);
    });

    test('returns absolute paths that resolve under the library root',
        () async {
      mkdir(p.join('完結済み', '異世界'));

      final result = await service.listDownloadDestinationFolders(
        tempDir.path,
        const <String>{},
      );

      for (final entry in result) {
        expect(p.isWithin(tempDir.path, entry.path), isTrue);
      }
      final nested = result.firstWhere((e) => e.name == '異世界');
      expect(p.equals(nested.path, p.join(tempDir.path, '完結済み', '異世界')),
          isTrue);
    });
  });
}
