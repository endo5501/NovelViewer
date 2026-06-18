import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:path/path.dart' as p;

NovelMetadata _novel(String folderName) => NovelMetadata(
      siteType: 'narou',
      novelId: folderName,
      title: 'title-$folderName',
      url: 'https://ncode.syosetu.com/$folderName/',
      folderName: folderName,
      episodeCount: 1,
      downloadedAt: DateTime(2024, 1, 1),
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('novel_viewer_dest_prov_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  void mkdir(String relative) {
    Directory(p.join(tempDir.path, relative)).createSync(recursive: true);
  }

  ProviderContainer makeContainer(List<NovelMetadata> novels) {
    final container = ProviderContainer(
      overrides: [
        libraryPathProvider.overrideWithValue(tempDir.path),
        allNovelsProvider.overrideWith((ref) async => novels),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('downloadDestinationFoldersProvider', () {
    test('returns organizational folders excluding novel folders', () async {
      mkdir('完結済み');
      mkdir('narou_n1234ab');

      final container = makeContainer([_novel('narou_n1234ab')]);

      final result = await container
          .read(downloadDestinationFoldersProvider.future);

      expect(result.map((e) => e.name).toList(), ['完結済み']);
    });

    test('sets displayName to the path relative to the library root',
        () async {
      mkdir(p.join('完結済み', '異世界'));

      final container = makeContainer(const []);

      final result = await container
          .read(downloadDestinationFoldersProvider.future);

      final nested = result.firstWhere((e) => e.name == '異世界');
      expect(nested.displayName, p.join('完結済み', '異世界'));
    });

    test('returns empty list when there are no organizational folders',
        () async {
      mkdir('narou_n1234ab');

      final container = makeContainer([_novel('narou_n1234ab')]);

      final result = await container
          .read(downloadDestinationFoldersProvider.future);

      expect(result, isEmpty);
    });

    test(
        'recomputes candidates between reads so folders created after the '
        'first read are not served stale (autoDispose)', () async {
      final container = makeContainer(const []);

      final first =
          await container.read(downloadDestinationFoldersProvider.future);
      expect(first, isEmpty);

      // A folder is created via the file browser after the dialog's first read.
      mkdir('完結済み');
      // Let the autoDispose disposal (scheduled on losing the last listener)
      // run so the next read recomputes from the current filesystem.
      await Future<void>.delayed(Duration.zero);

      final second =
          await container.read(downloadDestinationFoldersProvider.future);
      expect(second.map((e) => e.name), ['完結済み']);
    });
  });
}
