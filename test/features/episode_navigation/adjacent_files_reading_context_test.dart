import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/providers/adjacent_files_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_context/providers/reading_context_providers.dart';

class _FakeFileSystemService extends FileSystemService {
  _FakeFileSystemService(this._filesByDir);

  final Map<String, List<String>> _filesByDir;

  @override
  Future<List<FileEntry>> listTextFiles(String directoryPath) async => [
    for (final name in _filesByDir[directoryPath] ?? const <String>[])
      FileEntry(name: name, path: '$directoryPath/$name'),
  ];

  @override
  Future<List<DirectoryEntry>> listSubdirectories(String _) async => const [];
}

final _novel = NovelMetadata(
  siteType: 'narou',
  novelId: 'n1234ab',
  title: '異世界転生物語',
  url: 'https://ncode.syosetu.com/n1234ab/',
  folderName: 'narou_n1234ab',
  episodeCount: 5,
  downloadedAt: DateTime(2024, 1, 1),
);

const _novelDir = '/library/narou_n1234ab';
const _otherDir = '/library/narou_other';

void main() {
  /// Opens [openFile] in the viewer while the browser sits at
  /// [browserDirectory] — the two are independent since the drawer.
  Future<ProviderContainer> open(
    String? openFile, {
    String browserDirectory = _novelDir,
    Map<String, List<String>> tree = const {
      _novelDir: ['1.txt', '2.txt', '3.txt', '4.txt', '5.txt'],
      _otherDir: ['a.txt'],
      '/library': <String>[],
    },
  }) async {
    final c = ProviderContainer(
      overrides: [
        libraryPathProvider.overrideWithValue('/library'),
        allNovelsProvider.overrideWith((ref) => [_novel]),
        fileSystemServiceProvider.overrideWithValue(
          _FakeFileSystemService(tree),
        ),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier(browserDirectory),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(allNovelsProvider.future);
    if (openFile != null) {
      c
          .read(selectedFileProvider.notifier)
          .selectFile(
            FileEntry(name: openFile.split('/').last, path: openFile),
          );
    }
    await c.read(readingEpisodesProvider.future);
    return c;
  }

  group('adjacentFilesProvider は読書コンテキストに従う', () {
    test('ブラウザが小説フォルダにいるとき前後を返す', () async {
      final c = await open('$_novelDir/3.txt');

      final a = c.read(adjacentFilesProvider);
      expect(a.prev?.name, '2.txt');
      expect(a.next?.name, '4.txt');
    });

    test('ブラウザをライブラリルートへ移しても前後を返し続ける', () async {
      // The reader opened the drawer to look for what to read next, went up to
      // the library root and closed it again without choosing. Paging past the
      // end of the episode must still advance.
      final c = await open('$_novelDir/3.txt', browserDirectory: '/library');

      final a = c.read(adjacentFilesProvider);
      expect(a.prev?.name, '2.txt');
      expect(a.next?.name, '4.txt');
    });

    test('ブラウザを別の小説フォルダへ移しても変わらない', () async {
      final c = await open('$_novelDir/3.txt', browserDirectory: _otherDir);

      final a = c.read(adjacentFilesProvider);
      expect(a.prev?.name, '2.txt');
      expect(a.next?.name, '4.txt');
    });

    test('先頭のエピソードでは前が無い', () async {
      final c = await open('$_novelDir/1.txt', browserDirectory: '/library');

      final a = c.read(adjacentFilesProvider);
      expect(a.prev, isNull);
      expect(a.next?.name, '2.txt');
    });

    test('末尾のエピソードでは次が無い', () async {
      final c = await open('$_novelDir/5.txt', browserDirectory: '/library');

      final a = c.read(adjacentFilesProvider);
      expect(a.prev?.name, '4.txt');
      expect(a.next, isNull);
    });

    test('エピソードが1つだけなら前後とも無い', () async {
      final c = await open('$_otherDir/a.txt', browserDirectory: '/library');

      final a = c.read(adjacentFilesProvider);
      expect(a.prev, isNull);
      expect(a.next, isNull);
    });

    test('何も開いていなければ前後とも無い', () async {
      final c = await open(null);

      final a = c.read(adjacentFilesProvider);
      expect(a.prev, isNull);
      expect(a.next, isNull);
    });

    test('表示中のファイルが一覧に無ければ前後とも無い', () async {
      final c = await open('$_novelDir/削除済み.txt');

      final a = c.read(adjacentFilesProvider);
      expect(a.prev, isNull);
      expect(a.next, isNull);
    });
  });
}
