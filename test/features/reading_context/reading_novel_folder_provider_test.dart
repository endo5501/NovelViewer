import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_context/providers/reading_context_providers.dart';
import 'package:path/path.dart' as p;

final _novel = NovelMetadata(
  siteType: 'narou',
  novelId: 'n1234ab',
  title: '異世界転生物語',
  url: 'https://ncode.syosetu.com/n1234ab/',
  folderName: 'narou_n1234ab',
  episodeCount: 10,
  downloadedAt: DateTime(2024, 1, 1),
);

/// Builds a container with the library, the registered novels, the file on
/// screen and — deliberately separate — where the file browser happens to be.
Future<ProviderContainer> _container({
  String? openFilePath,
  List<NovelMetadata> novels = const [],
  String libraryPath = '/library',
  String? browserDirectory,
}) async {
  final container = ProviderContainer(
    overrides: [
      libraryPathProvider.overrideWithValue(libraryPath),
      allNovelsProvider.overrideWith((ref) => novels),
      currentDirectoryProvider.overrideWith(
        () => CurrentDirectoryNotifier(browserDirectory ?? libraryPath),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(allNovelsProvider.future);

  if (openFilePath != null) {
    container
        .read(selectedFileProvider.notifier)
        .selectFile(
          FileEntry(name: openFilePath.split('/').last, path: openFilePath),
        );
  }
  return container;
}

void main() {
  group('readingNovelFolderProvider', () {
    test('表示中のファイルが無いときnullを返す', () async {
      final container = await _container(novels: [_novel]);

      expect(container.read(readingNovelFolderProvider), isNull);
    });

    test('登録済み小説のエピソードからその小説フォルダを解決する', () async {
      final container = await _container(
        openFilePath: '/library/narou_n1234ab/0002.txt',
        novels: [_novel],
      );

      expect(
        container.read(readingNovelFolderProvider),
        p.join('/library', 'narou_n1234ab'),
      );
    });

    test('整理用サブフォルダに入れ子でも最も近い登録済みフォルダを解決する', () async {
      final container = await _container(
        openFilePath: '/library/完結済み/異世界/narou_n1234ab/0002.txt',
        novels: [_novel],
      );

      expect(
        container.read(readingNovelFolderProvider),
        p.join('/library', '完結済み', '異世界', 'narou_n1234ab'),
      );
    });

    test('登録済み小説フォルダを含まないパスではファイルの親フォルダを返す', () async {
      // A hand-placed text file is still something the reader is reading, and
      // the title has always fallen back to its folder name.
      final container = await _container(
        openFilePath: '/library/手動保存/001.txt',
        novels: [_novel],
      );

      expect(container.read(readingNovelFolderProvider), '/library/手動保存');
    });

    test('小説がひとつも登録されていなくても親フォルダを返す', () async {
      final container = await _container(
        openFilePath: '/library/narou_n1234ab/0002.txt',
      );

      expect(
        container.read(readingNovelFolderProvider),
        '/library/narou_n1234ab',
      );
    });

    test('ファイルブラウザの現在地は読書中の小説フォルダを変えない', () async {
      final atRoot = await _container(
        openFilePath: '/library/narou_n1234ab/0002.txt',
        novels: [_novel],
        browserDirectory: '/library',
      );
      final elsewhere = await _container(
        openFilePath: '/library/narou_n1234ab/0002.txt',
        novels: [_novel],
        browserDirectory: '/library/完結済み',
      );

      for (final container in [atRoot, elsewhere]) {
        expect(
          container.read(readingNovelFolderProvider),
          p.join('/library', 'narou_n1234ab'),
        );
      }
    });
  });
}
