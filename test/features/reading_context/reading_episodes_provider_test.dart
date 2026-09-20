import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_context/providers/reading_context_providers.dart';

/// Serves a fixed tree and records which directories were asked for, so the
/// test can tell the reading listing apart from the browser's own.
class _RecordingFileSystemService extends FileSystemService {
  _RecordingFileSystemService(this._filesByDir);

  final Map<String, List<String>> _filesByDir;
  final listedForText = <String>[];
  final listedForSubdirs = <String>[];

  @override
  Future<List<FileEntry>> listTextFiles(String directoryPath) async {
    listedForText.add(directoryPath);
    return [
      for (final name in _filesByDir[directoryPath] ?? const <String>[])
        FileEntry(name: name, path: '$directoryPath/$name'),
    ];
  }

  @override
  Future<List<DirectoryEntry>> listSubdirectories(String directoryPath) async {
    listedForSubdirs.add(directoryPath);
    return const [];
  }
}

final _novel = NovelMetadata(
  siteType: 'narou',
  novelId: 'n1234ab',
  title: '異世界転生物語',
  url: 'https://ncode.syosetu.com/n1234ab/',
  folderName: 'narou_n1234ab',
  episodeCount: 3,
  downloadedAt: DateTime(2024, 1, 1),
);

void main() {
  late _RecordingFileSystemService fs;

  Future<ProviderContainer> container({
    String? openFilePath,
    String browserDirectory = '/library',
    Map<String, List<String>> tree = const {},
  }) async {
    fs = _RecordingFileSystemService(tree);
    final c = ProviderContainer(
      overrides: [
        libraryPathProvider.overrideWithValue('/library'),
        allNovelsProvider.overrideWith((ref) async => [_novel]),
        fileSystemServiceProvider.overrideWithValue(fs),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier(browserDirectory),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(allNovelsProvider.future);
    if (openFilePath != null) {
      c
          .read(selectedFileProvider.notifier)
          .selectFile(
            FileEntry(name: openFilePath.split('/').last, path: openFilePath),
          );
    }
    return c;
  }

  const novelDir = '/library/narou_n1234ab';

  group('readingEpisodesProvider', () {
    test('読書中の小説フォルダのテキストファイルを返す', () async {
      final c = await container(
        openFilePath: '$novelDir/0002.txt',
        tree: {
          novelDir: ['0001.txt', '0002.txt', '0003.txt'],
        },
      );

      final episodes = await c.read(readingEpisodesProvider.future);
      expect(episodes.map((e) => e.name), ['0001.txt', '0002.txt', '0003.txt']);
    });

    test('並び順は数値プレフィックスソートと一致する', () async {
      final c = await container(
        openFilePath: '$novelDir/2.txt',
        tree: {
          novelDir: ['10.txt', '2.txt', '1.txt'],
        },
      );

      final episodes = await c.read(readingEpisodesProvider.future);
      // Lexical order would put 10 before 2; the numeric prefix rule does not.
      expect(episodes.map((e) => e.name), ['1.txt', '2.txt', '10.txt']);
    });

    test('ブラウザがライブラリルートにいても小説フォルダの一覧を返す', () async {
      final c = await container(
        openFilePath: '$novelDir/0002.txt',
        browserDirectory: '/library',
        tree: {
          novelDir: ['0001.txt', '0002.txt', '0003.txt'],
          '/library': ['よそのメモ.txt'],
        },
      );

      final episodes = await c.read(readingEpisodesProvider.future);
      expect(episodes.map((e) => e.name), ['0001.txt', '0002.txt', '0003.txt']);
    });

    test('読書コンテキストが無いときは空を返す', () async {
      final c = await container(
        tree: {
          novelDir: ['0001.txt'],
        },
      );

      expect(await c.read(readingEpisodesProvider.future), isEmpty);
    });

    test('サブディレクトリを列挙しない', () async {
      // The browser's listing needs subdirectories and TTS status; the reading
      // listing needs neither, and opening a second per-folder database would
      // escape the handle release keyed to the browser's directory.
      final c = await container(
        openFilePath: '$novelDir/0001.txt',
        tree: {
          novelDir: ['0001.txt'],
        },
      );

      await c.read(readingEpisodesProvider.future);
      expect(fs.listedForText, contains(novelDir));
      expect(fs.listedForSubdirs, isEmpty);
    });

    test('同じ小説の別エピソードへ移っても一覧を取り直さない', () async {
      final c = await container(
        openFilePath: '$novelDir/0001.txt',
        tree: {
          novelDir: ['0001.txt', '0002.txt'],
        },
      );
      await c.read(readingEpisodesProvider.future);
      final listingsAfterFirst = fs.listedForText.length;

      c
          .read(selectedFileProvider.notifier)
          .selectFile(
            const FileEntry(name: '0002.txt', path: '$novelDir/0002.txt'),
          );
      await c.read(readingEpisodesProvider.future);

      expect(fs.listedForText.length, listingsAfterFirst);
    });
  });
}
