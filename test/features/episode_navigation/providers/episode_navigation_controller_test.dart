import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/domain/file_entry_start_intent.dart';
import 'package:novel_viewer/features/episode_navigation/providers/episode_navigation_controller.dart';
import 'package:novel_viewer/features/episode_navigation/providers/pending_file_entry_intent_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

class _StubSelectedFileNotifier extends SelectedFileNotifier {
  final FileEntry? _initial;
  _StubSelectedFileNotifier(this._initial);

  @override
  FileEntry? build() => _initial;
}

List<FileEntry> _files(int count) {
  return List.generate(
    count,
    (i) => FileEntry(
      name: '${(i + 1).toString().padLeft(3, '0')}.txt',
      path: '/novel/${(i + 1).toString().padLeft(3, '0')}.txt',
    ),
  );
}

ProviderContainer _makeContainer({
  required List<FileEntry> files,
  required FileEntry? selected,
}) {
  return ProviderContainer(
    overrides: [
      directoryContentsProvider.overrideWith((ref) async {
        return DirectoryContents(files: files, subdirectories: const []);
      }),
      selectedFileProvider
          .overrideWith(() => _StubSelectedFileNotifier(selected)),
    ],
  );
}

void main() {
  group('EpisodeNavigationController', () {
    test('navigateToNext sets intent=fromStart and switches selectedFile',
        () async {
      final files = _files(3);
      final container = _makeContainer(files: files, selected: files[0]);
      addTearDown(container.dispose);
      await container.read(directoryContentsProvider.future);

      container.read(episodeNavigationControllerProvider).navigateToNext();

      expect(container.read(pendingFileEntryIntentProvider),
          FileEntryStartIntent.fromStart);
      expect(container.read(selectedFileProvider), files[1]);
    });

    test('navigateToPrevious sets intent=fromEnd and switches selectedFile',
        () async {
      final files = _files(3);
      final container = _makeContainer(files: files, selected: files[2]);
      addTearDown(container.dispose);
      await container.read(directoryContentsProvider.future);

      container.read(episodeNavigationControllerProvider).navigateToPrevious();

      expect(container.read(pendingFileEntryIntentProvider),
          FileEntryStartIntent.fromEnd);
      expect(container.read(selectedFileProvider), files[1]);
    });

    test('navigateToNext at last file is a no-op (intent + selection unchanged)',
        () async {
      final files = _files(3);
      final container = _makeContainer(files: files, selected: files.last);
      addTearDown(container.dispose);
      await container.read(directoryContentsProvider.future);

      container.read(episodeNavigationControllerProvider).navigateToNext();

      expect(container.read(pendingFileEntryIntentProvider), isNull);
      expect(container.read(selectedFileProvider), files.last);
    });

    test('navigateToPrevious at first file is a no-op', () async {
      final files = _files(3);
      final container = _makeContainer(files: files, selected: files.first);
      addTearDown(container.dispose);
      await container.read(directoryContentsProvider.future);

      container.read(episodeNavigationControllerProvider).navigateToPrevious();

      expect(container.read(pendingFileEntryIntentProvider), isNull);
      expect(container.read(selectedFileProvider), files.first);
    });

    test('navigateToNext with no selection is a no-op', () async {
      final files = _files(3);
      final container = _makeContainer(files: files, selected: null);
      addTearDown(container.dispose);
      await container.read(directoryContentsProvider.future);

      container.read(episodeNavigationControllerProvider).navigateToNext();

      expect(container.read(pendingFileEntryIntentProvider), isNull);
      expect(container.read(selectedFileProvider), isNull);
    });

    test('intent is set BEFORE selectedFile changes', () async {
      // The viewer listens to selectedFile changes; when it observes a new
      // file it must already see the intent in place. This test asserts the
      // ordering by snapshotting both values inside a `listen` callback
      // wired to `selectedFileProvider`.
      final files = _files(3);
      final container = _makeContainer(files: files, selected: files[0]);
      addTearDown(container.dispose);
      await container.read(directoryContentsProvider.future);

      FileEntryStartIntent? observedIntentWhenSelectionChanged;
      container.listen<FileEntry?>(selectedFileProvider, (prev, next) {
        observedIntentWhenSelectionChanged =
            container.read(pendingFileEntryIntentProvider);
      });

      container.read(episodeNavigationControllerProvider).navigateToNext();

      expect(observedIntentWhenSelectionChanged,
          FileEntryStartIntent.fromStart);
    });
  });
}
