import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';

class _UpsertCall {
  final String novelId;
  final String filePath;
  final String fileName;
  const _UpsertCall({
    required this.novelId,
    required this.filePath,
    required this.fileName,
  });
}

class _FakeRepository implements ReadingProgressRepository {
  final List<_UpsertCall> upsertCalls = [];
  ReadingProgress? Function(String novelId) onFindByNovelId;
  Future<void> Function()? upsertSideEffect;
  Future<void> Function()? findSideEffect;

  _FakeRepository({
    this.onFindByNovelId = _alwaysNull,
  });

  static ReadingProgress? _alwaysNull(String _) => null;

  @override
  Future<void> upsert({
    required String novelId,
    required String filePath,
    required String fileName,
  }) async {
    if (upsertSideEffect != null) await upsertSideEffect!();
    upsertCalls.add(_UpsertCall(
      novelId: novelId,
      filePath: filePath,
      fileName: fileName,
    ));
  }

  @override
  Future<ReadingProgress?> findByNovelId(String novelId) async {
    if (findSideEffect != null) await findSideEffect!();
    return onFindByNovelId(novelId);
  }

  @override
  Future<void> deleteByNovelId(String novelId) async {}
}

ProviderContainer _buildContainer({
  required _FakeRepository repository,
  String libraryPath = '/library',
  String initialDirectory = '/library',
  Map<String, DirectoryContents> contentsByPath = const {},
}) {
  return ProviderContainer(
    overrides: [
      libraryPathProvider.overrideWithValue(libraryPath),
      currentDirectoryProvider
          .overrideWith(() => CurrentDirectoryNotifier(initialDirectory)),
      readingProgressRepositoryProvider.overrideWithValue(repository),
      directoryContentsProvider.overrideWith((ref) async {
        final dir = ref.watch(currentDirectoryProvider);
        if (dir == null) return DirectoryContents.empty();
        return contentsByPath[dir] ?? DirectoryContents.empty();
      }),
    ],
  );
}

void main() {
  group('readingProgressAutoSaveListenerProvider', () {
    test('upserts when selectedFile transitions to a non-null entry inside a novel folder',
        () async {
      final repo = _FakeRepository();
      final container = _buildContainer(
        repository: repo,
        initialDirectory: '/library/narou_n1234ab',
      );
      addTearDown(container.dispose);

      container.read(readingProgressAutoSaveListenerProvider);

      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(
              name: '003_chapter3.txt',
              path: '/library/narou_n1234ab/003_chapter3.txt',
            ),
          );
      // Yield to allow the async upsert in the listener callback to run.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repo.upsertCalls.length, 1);
      expect(repo.upsertCalls.first.novelId, 'narou_n1234ab');
      expect(repo.upsertCalls.first.filePath,
          '/library/narou_n1234ab/003_chapter3.txt');
      expect(repo.upsertCalls.first.fileName, '003_chapter3.txt');
    });

    test('does not upsert at the library root (no novel id can be resolved)',
        () async {
      final repo = _FakeRepository();
      final container = _buildContainer(
        repository: repo,
        initialDirectory: '/library',
      );
      addTearDown(container.dispose);

      container.read(readingProgressAutoSaveListenerProvider);

      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(name: 'note.txt', path: '/library/note.txt'),
          );
      await Future<void>.delayed(Duration.zero);

      expect(repo.upsertCalls, isEmpty);
    });

    test('does not upsert when selectedFile transitions to null', () async {
      final repo = _FakeRepository();
      final container = _buildContainer(
        repository: repo,
        initialDirectory: '/library/narou_n1234ab',
      );
      addTearDown(container.dispose);

      container.read(readingProgressAutoSaveListenerProvider);

      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(
              name: '003_chapter3.txt',
              path: '/library/narou_n1234ab/003_chapter3.txt',
            ),
          );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      repo.upsertCalls.clear();
      container.read(selectedFileProvider.notifier).clear();
      await Future<void>.delayed(Duration.zero);

      expect(repo.upsertCalls, isEmpty);
    });

    test('repository failure is logged but does not crash the listener',
        () async {
      final repo = _FakeRepository();
      repo.upsertSideEffect = () async {
        throw StateError('boom');
      };
      final container = _buildContainer(
        repository: repo,
        initialDirectory: '/library/narou_n1234ab',
      );
      addTearDown(container.dispose);

      container.read(readingProgressAutoSaveListenerProvider);

      // Must not throw and must not break subsequent listener invocations.
      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(
              name: '003_chapter3.txt',
              path: '/library/narou_n1234ab/003_chapter3.txt',
            ),
          );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      // No assertion needed beyond "did not throw" — the test fails on
      // uncaught async errors otherwise.
    });
  });

  group('readingProgressAutoOpenListenerProvider', () {
    const novelFolder = '/library/narou_n1234ab';
    const chapter3 = FileEntry(
      name: '003_chapter3.txt',
      path: '/library/narou_n1234ab/003_chapter3.txt',
    );
    const chapter5 = FileEntry(
      name: '005_chapter5.txt',
      path: '/library/narou_n1234ab/005_chapter5.txt',
    );
    final folderContentsWith3and5 = DirectoryContents(
      files: const [chapter3, chapter5],
      subdirectories: const [],
    );

    test('entering a novel folder with stored progress selects that file',
        () async {
      final repo = _FakeRepository(
        onFindByNovelId: (id) => id == 'narou_n1234ab'
            ? ReadingProgress(
                novelId: 'narou_n1234ab',
                filePath: chapter3.path,
                fileName: chapter3.name,
                updatedAt: DateTime(2026, 5, 26),
              )
            : null,
      );
      final container = _buildContainer(
        repository: repo,
        initialDirectory: '/library',
        contentsByPath: {novelFolder: folderContentsWith3and5},
      );
      addTearDown(container.dispose);

      container.read(readingProgressAutoOpenListenerProvider);

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory(novelFolder);
      // Allow the future for directoryContents and the chained await chain
      // inside the listener to resolve.
      await container.read(directoryContentsProvider.future);
      await Future<void>.delayed(Duration.zero);

      final selected = container.read(selectedFileProvider);
      expect(selected, isNotNull);
      expect(selected!.path, chapter3.path);
    });

    test('does nothing when the novel has no stored progress', () async {
      final repo = _FakeRepository();
      final container = _buildContainer(
        repository: repo,
        initialDirectory: '/library',
        contentsByPath: {novelFolder: folderContentsWith3and5},
      );
      addTearDown(container.dispose);

      container.read(readingProgressAutoOpenListenerProvider);

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory(novelFolder);
      await container.read(directoryContentsProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(selectedFileProvider), isNull);
    });

    test('does nothing when the stored file is no longer in the directory',
        () async {
      final repo = _FakeRepository(
        onFindByNovelId: (id) => ReadingProgress(
          novelId: 'narou_n1234ab',
          filePath: '/library/narou_n1234ab/099_removed.txt',
          fileName: '099_removed.txt',
          updatedAt: DateTime(2026, 5, 26),
        ),
      );
      final container = _buildContainer(
        repository: repo,
        initialDirectory: '/library',
        contentsByPath: {novelFolder: folderContentsWith3and5},
      );
      addTearDown(container.dispose);

      container.read(readingProgressAutoOpenListenerProvider);

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory(novelFolder);
      await container.read(directoryContentsProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(selectedFileProvider), isNull);
    });

    test('does not fire when transitioning to the library root', () async {
      final repo = _FakeRepository(
        onFindByNovelId: (id) => ReadingProgress(
          novelId: id,
          filePath: chapter3.path,
          fileName: chapter3.name,
          updatedAt: DateTime(2026, 5, 26),
        ),
      );
      final container = _buildContainer(
        repository: repo,
        initialDirectory: novelFolder,
        contentsByPath: {novelFolder: folderContentsWith3and5},
      );
      addTearDown(container.dispose);

      container.read(readingProgressAutoOpenListenerProvider);

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory('/library');
      await Future<void>.delayed(Duration.zero);

      // The transition was novel folder → library root. No auto-open SHALL
      // fire at the library root.
      expect(container.read(selectedFileProvider), isNull);
    });

    test('does not override an existing selection belonging to this novel',
        () async {
      final repo = _FakeRepository(
        onFindByNovelId: (id) => ReadingProgress(
          novelId: 'narou_n1234ab',
          filePath: chapter3.path,
          fileName: chapter3.name,
          updatedAt: DateTime(2026, 5, 26),
        ),
      );
      final container = _buildContainer(
        repository: repo,
        initialDirectory: '/library',
        contentsByPath: {novelFolder: folderContentsWith3and5},
      );
      addTearDown(container.dispose);

      container.read(readingProgressAutoOpenListenerProvider);

      // Sibling code path: selection set immediately before directory
      // changes, e.g. an external navigation flow.
      container.read(selectedFileProvider.notifier).selectFile(chapter5);
      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory(novelFolder);
      await container.read(directoryContentsProvider.future);
      await Future<void>.delayed(Duration.zero);

      // Existing selection SHALL stand; auto-open MUST NOT overwrite.
      expect(container.read(selectedFileProvider)!.path, chapter5.path);
    });

    test('repository read failure is logged and selection is left untouched',
        () async {
      final repo = _FakeRepository();
      repo.findSideEffect = () async {
        throw StateError('read failed');
      };
      final container = _buildContainer(
        repository: repo,
        initialDirectory: '/library',
        contentsByPath: {novelFolder: folderContentsWith3and5},
      );
      addTearDown(container.dispose);

      container.read(readingProgressAutoOpenListenerProvider);

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory(novelFolder);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(selectedFileProvider), isNull);
    });
  });
}
