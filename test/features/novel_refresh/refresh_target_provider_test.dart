import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_refresh/providers/refresh_target_provider.dart';

/// The novel the reader is looking at in most of these cases.
final _narouNovel = NovelMetadata(
  siteType: 'narou',
  novelId: 'n1234ab',
  title: '異世界転生物語',
  url: 'https://ncode.syosetu.com/n1234ab/',
  folderName: 'narou_n1234ab',
  episodeCount: 10,
  downloadedAt: DateTime(2024, 1, 1),
);

/// A generic-web collection: a curated set of articles, not a re-fetchable
/// novel, so it is never a refresh target.
final _webCollection = NovelMetadata(
  siteType: 'web',
  novelId: 'abc123',
  title: '気になった記事',
  url: 'https://example.com/article',
  folderName: 'web_abc123',
  episodeCount: 3,
  downloadedAt: DateTime(2024, 1, 1),
);

/// Builds a container with the library, the registered novels and the file the
/// text viewer is showing. [currentDirectory] is the file browser's own
/// location, which the target must not depend on.
Future<ProviderContainer> _container({
  String? selectedFilePath,
  List<NovelMetadata> novels = const [],
  String libraryPath = '/library',
  String? currentDirectory,
}) async {
  final container = ProviderContainer(
    overrides: [
      libraryPathProvider.overrideWithValue(libraryPath),
      allNovelsProvider.overrideWith((ref) => novels),
      currentDirectoryProvider.overrideWith(
        () => CurrentDirectoryNotifier(currentDirectory ?? libraryPath),
      ),
    ],
  );
  addTearDown(container.dispose);

  // The target reads the novel list synchronously, so let it settle first.
  await container.read(allNovelsProvider.future);

  if (selectedFilePath != null) {
    container
        .read(selectedFileProvider.notifier)
        .selectFile(
          FileEntry(
            name: selectedFilePath.split('/').last,
            path: selectedFilePath,
          ),
        );
  }
  return container;
}

void main() {
  group('refreshTargetProvider', () {
    test('表示中のファイルが無いときnullを返す', () async {
      final container = await _container(novels: [_narouNovel]);

      expect(container.read(refreshTargetProvider), isNull);
    });

    test('登録済み小説のエピソードを表示しているとき対象を解決する', () async {
      final container = await _container(
        selectedFilePath: '/library/narou_n1234ab/0001_episode.txt',
        novels: [_narouNovel],
      );

      final target = container.read(refreshTargetProvider);
      expect(target, isNotNull);
      expect(target!.folderName, 'narou_n1234ab');
      expect(target.parentPath, '/library');
      expect(target.title, '異世界転生物語');
    });

    test('整理用サブフォルダに入れ子の小説は、その親をparentPathとする', () async {
      final container = await _container(
        selectedFilePath: '/library/完結済み/異世界/narou_n1234ab/0005_episode.txt',
        novels: [_narouNovel],
      );

      final target = container.read(refreshTargetProvider);
      expect(target, isNotNull);
      expect(target!.folderName, 'narou_n1234ab');
      expect(target.parentPath, '/library/完結済み/異世界');
    });

    test('登録済み小説フォルダを含まないパスのファイルはnullを返す', () async {
      final container = await _container(
        selectedFilePath: '/library/メモ/走り書き.txt',
        novels: [_narouNovel],
      );

      expect(container.read(refreshTargetProvider), isNull);
    });

    test('Web記事コレクションのエピソードはnullを返す', () async {
      final container = await _container(
        selectedFilePath: '/library/web_abc123/0002_article.txt',
        novels: [_narouNovel, _webCollection],
      );

      expect(container.read(refreshTargetProvider), isNull);
    });

    test('ファイルブラウザの現在地は対象を変えない', () async {
      // The reader is part-way through one novel and has taken the drawer
      // somewhere else entirely — the library root, or another novel.
      final atRoot = await _container(
        selectedFilePath: '/library/narou_n1234ab/0001_episode.txt',
        novels: [_narouNovel, _webCollection],
        currentDirectory: '/library',
      );
      final atOtherNovel = await _container(
        selectedFilePath: '/library/narou_n1234ab/0001_episode.txt',
        novels: [_narouNovel, _webCollection],
        currentDirectory: '/library/web_abc123',
      );

      for (final container in [atRoot, atOtherNovel]) {
        final target = container.read(refreshTargetProvider);
        expect(target, isNotNull);
        expect(target!.folderName, 'narou_n1234ab');
        expect(target.parentPath, '/library');
      }
    });

    test('小説がひとつも登録されていないときnullを返す', () async {
      final container = await _container(
        selectedFilePath: '/library/narou_n1234ab/0001_episode.txt',
      );

      expect(container.read(refreshTargetProvider), isNull);
    });
  });
}
