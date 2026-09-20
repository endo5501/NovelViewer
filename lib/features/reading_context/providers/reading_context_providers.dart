import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/shared/utils/novel_id_resolver.dart';
import 'package:path/path.dart' as p;

/// The folder the open episode actually sits in, or null when the text viewer
/// is showing nothing.
///
/// This is what the episodes beside it are: the files alongside it on disk.
/// A novel folder may hold organisational subfolders of its own, and an
/// episode inside one belongs to that subfolder's run, not to the novel
/// folder's top level.
final readingEpisodeFolderProvider = Provider<String?>((ref) {
  final selected = ref.watch(selectedFileProvider);
  if (selected == null) return null;
  return p.dirname(selected.path);
});

/// The absolute path of the novel folder the reader currently has open, or
/// null when the text viewer is showing nothing.
///
/// Resolved from [selectedFileProvider] — the episode on screen — and never
/// from [currentDirectoryProvider]. Since the file browser moved into a
/// drawer, its location is where the reader is looking for what to read next;
/// it says nothing about what they are reading now. Anything that describes
/// the open episode belongs here rather than on the browser's listing.
///
/// This names the *work*, which is what the app bar says. It is not where the
/// episodes are listed from — see [readingEpisodeFolderProvider], which they
/// differ from whenever a novel keeps episodes in a subfolder.
///
/// A path with no registered novel folder on it falls back to the episode's
/// own folder. A hand-placed text file is still something the reader is
/// reading, and the app bar has always named its folder.
final readingNovelFolderProvider = Provider<String?>((ref) {
  final selected = ref.watch(selectedFileProvider);
  if (selected == null) return null;

  final libraryPath = ref.watch(libraryPathProvider);
  final novels = ref.watch(allNovelsProvider).value ?? const <NovelMetadata>[];

  if (libraryPath != null && novels.isNotEmpty) {
    // The shared, nesting-aware rule, so the folder named here is the one
    // reading progress and the per-folder databases are keyed by.
    final resolved = resolveNovelFolderPath(libraryPath, selected.path, {
      for (final novel in novels) novel.folderName,
    });
    if (resolved != null) return resolved;
  }
  return ref.watch(readingEpisodeFolderProvider);
});

/// The episodes beside the one the reader has open, in the same order the file
/// browser would show them.
///
/// Deliberately not `directoryContentsProvider`. That one also enumerates
/// subdirectories, resolves novel titles, and — where a `tts_audio.db` exists —
/// opens a per-folder database to read TTS status. Those handles are released
/// when the *browser* leaves a folder, so a second listing opened for the
/// reading folder would sit outside that release path. Listing and sorting is
/// all this needs, and it touches no database.
///
/// It depends on the folder, not on the file, so turning the page inside one
/// folder rebuilds nothing — the watched value is unchanged. Moving to another
/// folder re-lists, which is also what makes an episode added outside the app
/// show up on the reader's next visit rather than never.
final readingEpisodesProvider = FutureProvider<List<FileEntry>>((ref) async {
  final folder = ref.watch(readingEpisodeFolderProvider);
  if (folder == null) return const [];

  final service = ref.watch(fileSystemServiceProvider);
  final files = await service.listTextFiles(folder);
  return service.sortByNumericPrefix(files);
});

/// Reloads both episode listings: the reader's and the file browser's.
///
/// They are separate providers over the same directories, so anything that can
/// add, remove or move episodes — a download, a refresh, a folder operation —
/// has to invalidate both. Going through one helper is what stops the next call
/// site from remembering only one of them, which would show up as episodes the
/// reader cannot page into.
///
/// [invalidate] is passed as a tear-off from a `WidgetRef`, a provider `Ref`
/// or a container, the way `releaseFolderDbHandles` already takes one, so the
/// widget flows and the provider flows share one implementation.
void invalidateEpisodeListings(void Function(ProviderOrFamily) invalidate) {
  invalidate(directoryContentsProvider);
  invalidate(readingEpisodesProvider);
}
