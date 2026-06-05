import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
}

NovelMetadata _novel(String folderName, String title) => NovelMetadata(
      siteType: 'narou',
      novelId: folderName.split('_').last,
      title: title,
      url: 'https://example.com/$folderName',
      folderName: folderName,
      episodeCount: 1,
      downloadedAt: DateTime(2024, 1, 1),
    );

void main() {
  late Directory libraryRoot;

  setUp(() {
    libraryRoot = Directory.systemTemp.createTempSync('dir_contents_title_');
  });

  tearDown(() {
    libraryRoot.deleteSync(recursive: true);
  });

  ProviderContainer containerFor(
    String currentDir,
    List<NovelMetadata> novels,
  ) {
    final container = ProviderContainer(
      overrides: [
        currentDirectoryProvider
            .overrideWith(() => _TestCurrentDirectoryNotifier(currentDir)),
        libraryPathProvider.overrideWithValue(libraryRoot.path),
        allNovelsProvider.overrideWith((ref) async => novels),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('maps registered novel folder to its title when nested below root',
      () async {
    final orgFolder = Directory('${libraryRoot.path}/完結済み')..createSync();
    Directory('${orgFolder.path}/narou_n1234ab').createSync();

    final container = containerFor(
      orgFolder.path,
      [_novel('narou_n1234ab', 'テスト小説')],
    );

    final contents = await container.read(directoryContentsProvider.future);

    final entry = contents.subdirectories
        .firstWhere((d) => d.name == 'narou_n1234ab');
    expect(entry.displayName, 'テスト小説');
  });

  test('keeps organizational folder name as-is (not a registered novel)',
      () async {
    Directory('${libraryRoot.path}/完結済み').createSync();

    final container = containerFor(
      libraryRoot.path,
      [_novel('narou_n1234ab', 'テスト小説')],
    );

    final contents = await container.read(directoryContentsProvider.future);

    final entry =
        contents.subdirectories.firstWhere((d) => d.name == '完結済み');
    expect(entry.displayName, '完結済み');
  });
}
