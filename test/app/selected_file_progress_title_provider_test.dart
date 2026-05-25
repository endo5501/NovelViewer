import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/app/selected_file_progress_title_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
}

class _StubSelectedFileNotifier extends SelectedFileNotifier {
  final FileEntry? _initial;
  _StubSelectedFileNotifier(this._initial);

  @override
  FileEntry? build() => _initial;
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
      name:
          '${(i + 1).toString().padLeft(3, '0')}-ep${i + 1}.txt',
      path:
          '$dir/${(i + 1).toString().padLeft(3, '0')}-ep${i + 1}.txt',
    ),
  );
}

ProviderContainer _makeContainer({
  required String? currentDir,
  required List<FileEntry> files,
  required FileEntry? selected,
  List<NovelMetadata>? novels,
  String libraryPath = '/library',
}) {
  return ProviderContainer(
    overrides: [
      libraryPathProvider.overrideWithValue(libraryPath),
      currentDirectoryProvider
          .overrideWith(() => _TestCurrentDirectoryNotifier(currentDir)),
      allNovelsProvider.overrideWith((ref) async => novels ?? [_novel]),
      directoryContentsProvider.overrideWith((ref) async {
        return DirectoryContents(files: files, subdirectories: const []);
      }),
      selectedFileProvider
          .overrideWith(() => _StubSelectedFileNotifier(selected)),
    ],
  );
}

Future<String> _readTitle(ProviderContainer container) async {
  await container.read(directoryContentsProvider.future);
  await container.read(selectedNovelTitleProvider.future);
  return container.read(selectedFileProgressTitleProvider);
}

void main() {
  group('selectedFileProgressTitleProvider', () {
    test('novel folder + file selected: composes "title — name (N/M)"',
        () async {
      final files = _files(200);
      final container = _makeContainer(
        currentDir: '/library/n1234',
        files: files,
        selected: files[48], // 49th, 1-indexed
      );
      addTearDown(container.dispose);

      final title = await _readTitle(container);
      expect(title, '異世界転生 — 049-ep49.txt (49/200)');
    });

    test('novel folder + no file selected: just the novel title', () async {
      final files = _files(200);
      final container = _makeContainer(
        currentDir: '/library/n1234',
        files: files,
        selected: null,
      );
      addTearDown(container.dispose);

      final title = await _readTitle(container);
      expect(title, '異世界転生');
    });

    test('library root: NovelViewer regardless of selection', () async {
      final container = _makeContainer(
        currentDir: '/library',
        files: const [],
        selected: null,
        libraryPath: '/library',
      );
      addTearDown(container.dispose);

      final title = await _readTitle(container);
      expect(title, 'NovelViewer');
    });

    test('unregistered folder: uses folder name as base', () async {
      final files = _files(3, dir: '/library/unknown');
      final container = _makeContainer(
        currentDir: '/library/unknown',
        files: files,
        selected: files[0],
      );
      addTearDown(container.dispose);

      final title = await _readTitle(container);
      expect(title, 'unknown — 001-ep1.txt (1/3)');
    });

    test('selected file not in listing: falls back to base title', () async {
      final files = _files(3);
      const orphan = FileEntry(name: 'x.txt', path: '/elsewhere/x.txt');
      final container = _makeContainer(
        currentDir: '/library/n1234',
        files: files,
        selected: orphan,
      );
      addTearDown(container.dispose);

      final title = await _readTitle(container);
      expect(title, '異世界転生');
    });

    test('empty file listing: just the base title', () async {
      final container = _makeContainer(
        currentDir: '/library/n1234',
        files: const [],
        selected: null,
      );
      addTearDown(container.dispose);

      final title = await _readTitle(container);
      expect(title, '異世界転生');
    });
  });
}
