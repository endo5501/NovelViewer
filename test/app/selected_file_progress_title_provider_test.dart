import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/app/selected_file_progress_title_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_context/providers/reading_context_providers.dart';

class _StubSelectedFileNotifier extends SelectedFileNotifier {
  _StubSelectedFileNotifier(this._initial);
  final FileEntry? _initial;

  @override
  FileEntry? build() => _initial;
}

class _FakeFileSystemService extends FileSystemService {
  _FakeFileSystemService(this._filesByDir);
  final Map<String, List<FileEntry>> _filesByDir;

  @override
  Future<List<FileEntry>> listTextFiles(String directoryPath) async =>
      _filesByDir[directoryPath] ?? const [];

  @override
  Future<List<DirectoryEntry>> listSubdirectories(String _) async => const [];
}

final _novel = NovelMetadata(
  siteType: 'narou',
  novelId: 'n1234',
  title: '異世界転生',
  url: 'https://ncode.syosetu.com/n1234/',
  folderName: 'n1234',
  episodeCount: 200,
  downloadedAt: DateTime(2024, 1, 1),
);

List<FileEntry> _files(int count, {String dir = '/library/n1234'}) {
  return List.generate(
    count,
    (i) => FileEntry(
      name: '${(i + 1).toString().padLeft(3, '0')}-ep${i + 1}.txt',
      path: '$dir/${(i + 1).toString().padLeft(3, '0')}-ep${i + 1}.txt',
    ),
  );
}

/// [browserDirectory] is where the file browser happens to be, which since the
/// drawer has nothing to do with what is on screen.
ProviderContainer _makeContainer({
  required FileEntry? open,
  required Map<String, List<FileEntry>> tree,
  String browserDirectory = '/library',
  List<NovelMetadata>? novels,
  String libraryPath = '/library',
}) {
  return ProviderContainer(
    overrides: [
      libraryPathProvider.overrideWithValue(libraryPath),
      currentDirectoryProvider.overrideWith(
        () => CurrentDirectoryNotifier(browserDirectory),
      ),
      allNovelsProvider.overrideWith((ref) async => novels ?? [_novel]),
      fileSystemServiceProvider.overrideWithValue(_FakeFileSystemService(tree)),
      selectedFileProvider.overrideWith(() => _StubSelectedFileNotifier(open)),
    ],
  );
}

Future<String> _readTitle(ProviderContainer container) async {
  await container.read(allNovelsProvider.future);
  await container.read(readingEpisodesProvider.future);
  return container.read(selectedFileProgressTitleProvider);
}

void main() {
  group('selectedFileProgressTitleProvider', () {
    test('小説のエピソードを開いていれば作品名とファイル名と進捗を並べる', () async {
      final files = _files(200);
      final container = _makeContainer(
        open: files[48], // 49th, 1-indexed
        tree: {'/library/n1234': files},
        browserDirectory: '/library/n1234',
      );
      addTearDown(container.dispose);

      expect(await _readTitle(container), '異世界転生 — 049-ep49.txt (49/200)');
    });

    test('ファイルブラウザをライブラリルートへ移してもタイトルは変わらない', () async {
      final files = _files(200);
      final container = _makeContainer(
        open: files[48],
        tree: {'/library/n1234': files, '/library': const []},
        browserDirectory: '/library',
      );
      addTearDown(container.dispose);

      expect(await _readTitle(container), '異世界転生 — 049-ep49.txt (49/200)');
    });

    test('ファイルブラウザを別の小説フォルダへ移してもタイトルは変わらない', () async {
      final files = _files(200);
      final otherFiles = _files(3, dir: '/library/n9999');
      final container = _makeContainer(
        open: files[48],
        tree: {'/library/n1234': files, '/library/n9999': otherFiles},
        browserDirectory: '/library/n9999',
      );
      addTearDown(container.dispose);

      expect(await _readTitle(container), '異世界転生 — 049-ep49.txt (49/200)');
    });

    test('何も開いていなければNovelViewerを表示する', () async {
      final container = _makeContainer(
        open: null,
        tree: {'/library': const []},
      );
      addTearDown(container.dispose);

      expect(await _readTitle(container), 'NovelViewer');
    });

    test('ブラウザが小説フォルダにいても、開いているエピソードが無ければNovelViewer', () async {
      // The title answers "what am I reading", and nothing is being read. The
      // reader only ever sees this with the drawer open over the app bar.
      final files = _files(200);
      final container = _makeContainer(
        open: null,
        tree: {'/library/n1234': files},
        browserDirectory: '/library/n1234',
      );
      addTearDown(container.dispose);

      expect(await _readTitle(container), 'NovelViewer');
    });

    test('メタデータ未登録のフォルダではフォルダ名とその件数を使う', () async {
      final files = _files(3, dir: '/library/unknown');
      final container = _makeContainer(
        open: files[0],
        tree: {'/library/unknown': files},
      );
      addTearDown(container.dispose);

      expect(await _readTitle(container), 'unknown — 001-ep1.txt (1/3)');
    });

    test('整理フォルダ配下に入れ子の小説でも作品名を表示する', () async {
      final files = _files(3, dir: '/library/完結済み/n1234');
      final container = _makeContainer(
        open: files[1],
        tree: {'/library/完結済み/n1234': files},
        browserDirectory: '/library',
      );
      addTearDown(container.dispose);

      expect(await _readTitle(container), '異世界転生 — 002-ep2.txt (2/3)');
    });

    test('小説フォルダのサブディレクトリのファイルでも作品名を表示する', () async {
      final files = _files(2, dir: '/library/n1234/extra');
      final container = _makeContainer(
        open: files[0],
        tree: {'/library/n1234/extra': files},
        browserDirectory: '/library',
      );
      addTearDown(container.dispose);

      // The nearest registered ancestor names it, whatever the depth, and the
      // progress counts the files it actually sits with.
      expect(await _readTitle(container), '異世界転生 — 001-ep1.txt (1/2)');
    });

    test('ライブラリルート直下のファイルはNovelViewerを名乗る', () async {
      // There is no novel to name: the library folder is not a work.
      final files = _files(2, dir: '/library');
      final container = _makeContainer(
        open: files[0],
        tree: {'/library': files},
      );
      addTearDown(container.dispose);

      expect(await _readTitle(container), 'NovelViewer — 001-ep1.txt (1/2)');
    });

    test('ライブラリ外のファイルはその親フォルダ名を使う', () async {
      final files = _files(1, dir: '/elsewhere');
      final container = _makeContainer(
        open: files[0],
        tree: {'/elsewhere': files},
      );
      addTearDown(container.dispose);

      expect(await _readTitle(container), 'elsewhere — 001-ep1.txt (1/1)');
    });

    test('開いているファイルが自身のフォルダの一覧に無ければ作品名のみ', () async {
      // The listing has not caught up, or the file was deleted underneath.
      final container = _makeContainer(
        open: const FileEntry(name: '消えた.txt', path: '/library/n1234/消えた.txt'),
        tree: {'/library/n1234': _files(3)},
      );
      addTearDown(container.dispose);

      expect(await _readTitle(container), '異世界転生');
    });

    test('フォルダに一話も無ければ作品名のみ', () async {
      final container = _makeContainer(
        open: const FileEntry(name: '001.txt', path: '/library/n1234/001.txt'),
        tree: {'/library/n1234': const []},
      );
      addTearDown(container.dispose);

      expect(await _readTitle(container), '異世界転生');
    });
  });
}
