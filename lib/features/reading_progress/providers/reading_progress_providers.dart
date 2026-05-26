import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';

final _log = Logger('reading_progress');

final readingProgressRepositoryProvider =
    Provider<ReadingProgressRepository>((ref) {
  return ReadingProgressRepository(ref.watch(novelDatabaseProvider));
});

/// Saves the current selection as the novel's last-opened file whenever the
/// user transitions [selectedFileProvider] to a non-null entry inside a novel
/// folder. Failures are logged at WARNING and otherwise swallowed so a
/// transient DB issue cannot bubble up into the UI mid-read.
final readingProgressAutoSaveListenerProvider = Provider<void>((ref) {
  ref.listen<FileEntry?>(selectedFileProvider, (_, next) async {
    if (next == null) return;
    final novelId = ref.read(currentNovelIdProvider);
    if (novelId == null) return;
    try {
      await ref.read(readingProgressRepositoryProvider).upsert(
            novelId: novelId,
            filePath: next.path,
            fileName: next.name,
          );
    } catch (e, st) {
      _log.warning(
        'Failed to save reading progress for $novelId at ${next.path}',
        e,
        st,
      );
    }
  });
});

/// One-shot auto-open: when [currentDirectoryProvider] transitions into a
/// novel folder, look up the novel's stored reading progress and select the
/// matching [FileEntry] from [directoryContentsProvider]. Skips the library
/// root, missing files, and any case where the user already has a file
/// selected for this novel.
final readingProgressAutoOpenListenerProvider = Provider<void>((ref) {
  ref.listen<String?>(currentDirectoryProvider, (previous, next) async {
    if (next == null) return;
    if (previous == next) return;

    final libraryPath = ref.read(libraryPathProvider);
    if (libraryPath == null) return;
    if (p.equals(next, libraryPath)) return;
    if (!p.isWithin(libraryPath, next)) return;

    final novelId = p.split(p.relative(next, from: libraryPath)).first;

    final ReadingProgress? progress;
    try {
      progress = await ref
          .read(readingProgressRepositoryProvider)
          .findByNovelId(novelId);
    } catch (e, st) {
      _log.warning(
        'Failed to read reading progress for $novelId',
        e,
        st,
      );
      return;
    }
    if (progress == null) return;

    // The directory contents future may still be pending. Capture the target
    // path so that a later transition (e.g. user already moved on) aborts
    // this auto-open instead of stomping on the new directory.
    final targetDir = next;
    final DirectoryContents contents;
    try {
      contents = await ref.read(directoryContentsProvider.future);
    } catch (e, st) {
      _log.warning(
        'Failed to load directory contents for auto-open in $novelId',
        e,
        st,
      );
      return;
    }
    if (ref.read(currentDirectoryProvider) != targetDir) return;

    FileEntry? match;
    for (final entry in contents.files) {
      if (entry.path == progress.filePath) {
        match = entry;
        break;
      }
    }
    if (match == null) return;

    // Don't trample a selection the user (or a sibling code path) put in
    // place between the directory transition and the awaited lookups.
    if (ref.read(selectedFileProvider) != null) return;
    ref.read(selectedFileProvider.notifier).selectFile(match);
  });
});
