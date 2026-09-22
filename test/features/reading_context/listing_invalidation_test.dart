import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/providers/adjacent_files_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_context/providers/reading_context_providers.dart';

/// A library whose episode count the test grows, the way a refresh does.
class _GrowingFileSystemService extends FileSystemService {
  var episodeCount = 2;

  @override
  Future<List<FileEntry>> listTextFiles(String directoryPath) async {
    if (directoryPath != _novelDir) return const [];
    return [
      for (var i = 1; i <= episodeCount; i++)
        FileEntry(name: '$i.txt', path: '$_novelDir/$i.txt'),
    ];
  }

  @override
  Future<List<DirectoryEntry>> listSubdirectories(String _) async => const [];
}

const _novelDir = '/library/narou_n1234ab';

final _novel = NovelMetadata(
  siteType: 'narou',
  novelId: 'n1234ab',
  title: '異世界転生物語',
  url: 'https://ncode.syosetu.com/n1234ab/',
  folderName: 'narou_n1234ab',
  episodeCount: 2,
  downloadedAt: DateTime(2024, 1, 1),
);

void main() {
  late _GrowingFileSystemService fs;

  Future<ProviderContainer> open() async {
    fs = _GrowingFileSystemService();
    final c = ProviderContainer(
      overrides: [
        libraryPathProvider.overrideWithValue('/library'),
        allNovelsProvider.overrideWith((ref) => [_novel]),
        fileSystemServiceProvider.overrideWithValue(fs),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier(_novelDir),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(allNovelsProvider.future);
    c
        .read(selectedFileProvider.notifier)
        .selectFile(const FileEntry(name: '2.txt', path: '$_novelDir/2.txt'));
    await c.read(readingEpisodesProvider.future);
    return c;
  }

  test('無効化ヘルパーは両方の一覧を読み直す', () async {
    final c = await open();
    await c.read(directoryContentsProvider.future);
    expect((await c.read(readingEpisodesProvider.future)).length, 2);
    expect((await c.read(directoryContentsProvider.future)).files.length, 2);

    // A refresh saved a third episode.
    fs.episodeCount = 3;

    invalidateEpisodeListings(c.invalidate);

    expect((await c.read(readingEpisodesProvider.future)).length, 3);
    expect((await c.read(directoryContentsProvider.future)).files.length, 3);
  });

  test('更新で増えたエピソードが話送りに現れる', () async {
    final c = await open();
    // The reader is on the last episode, so there is nothing after it yet.
    expect(c.read(adjacentFilesProvider).next, isNull);

    fs.episodeCount = 3;

    invalidateEpisodeListings(c.invalidate);
    await c.read(readingEpisodesProvider.future);

    expect(c.read(adjacentFilesProvider).next?.name, '3.txt');
  });
}
