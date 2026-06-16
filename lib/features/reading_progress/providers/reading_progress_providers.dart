import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';
import 'package:novel_viewer/shared/utils/novel_id_resolver.dart';

final _log = Logger('reading_progress');

final readingProgressRepositoryProvider =
    Provider<ReadingProgressRepository>((ref) {
  return ReadingProgressRepository(ref.watch(novelDatabaseProvider));
});

/// Monotonic counter bumped whenever reading progress is written. Consumers
/// that cache progress-derived state (e.g. the file browser's folder badges)
/// watch this to recompute after a save, since a write to one novel's
/// `reading_progress` row is otherwise invisible to a cached aggregate.
class ReadingProgressRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final readingProgressRevisionProvider =
    NotifierProvider<ReadingProgressRevision, int>(ReadingProgressRevision.new);

/// Saves the current selection as the novel's last-opened file whenever the
/// user transitions [selectedFileProvider] to a non-null entry inside a novel
/// folder. Failures are logged at WARNING and otherwise swallowed so a
/// transient DB issue cannot bubble up into the UI mid-read.
final readingProgressAutoSaveListenerProvider = Provider<void>((ref) {
  ref.listen<FileEntry?>(selectedFileProvider, (_, next) async {
    if (next == null) return;

    // Resolve the novel id from the selected file's own path using the shared
    // nesting-aware rule (nearest registered ancestor folder's leaf name).
    // Deriving it from `next.path` rather than a derived provider avoids any
    // dependency on Riverpod's invalidation order inside this callback.
    final libraryPath = ref.read(libraryPathProvider);
    if (libraryPath == null) return;
    final novels = await ref.read(allNovelsProvider.future);
    final registeredFolderNames = {for (final n in novels) n.folderName};
    final novelId = resolveNovelId(libraryPath, next.path, registeredFolderNames);
    if (novelId == null) return;
    try {
      await ref.read(readingProgressRepositoryProvider).upsert(
            novelId: novelId,
            fileName: next.name,
          );
      // Signal cached progress aggregates (folder badges) to refresh.
      ref.read(readingProgressRevisionProvider.notifier).bump();
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

    // Re-derive the novel id from the new directory using the shared
    // nesting-aware rule [resolveNovelId] (nearest registered ancestor folder's
    // leaf name = folder_name; library root / out-of-library / no registered
    // ancestor → null). Computing it from `next` directly avoids depending on
    // Riverpod's invalidation order for derived providers in a listener
    // callback.
    final libraryPath = ref.read(libraryPathProvider);
    if (libraryPath == null) return;
    final novels = await ref.read(allNovelsProvider.future);
    final registeredFolderNames = {for (final n in novels) n.folderName};
    final novelId = resolveNovelId(libraryPath, next, registeredFolderNames);
    if (novelId == null) return;

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
      // Match on file_name within the current directory listing rather than a
      // persisted absolute path, so a moved/renamed novel folder still
      // restores progress. `p.equals` compares the base names with the same
      // platform semantics the old absolute-path match used — notably
      // case-insensitive on Windows, where the FS is case-preserving but
      // case-insensitive.
      if (p.equals(entry.name, progress.fileName)) {
        match = entry;
        break;
      }
    }
    if (match == null) return;

    // Don't trample a selection that already points at a file inside this
    // novel folder — that's the spec's "belongs to this novel" carve-out for
    // sibling code paths that set a selection just before the transition. A
    // stale entry from a different novel falls through and is replaced.
    final existing = ref.read(selectedFileProvider);
    if (existing != null && p.isWithin(targetDir, existing.path)) return;
    ref.read(selectedFileProvider.notifier).selectFile(match);
  });
});
