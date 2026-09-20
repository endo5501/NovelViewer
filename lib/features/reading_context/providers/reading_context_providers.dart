import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/shared/utils/novel_id_resolver.dart';
import 'package:path/path.dart' as p;

/// The absolute path of the novel folder the reader currently has open, or
/// null when the text viewer is showing nothing.
///
/// Resolved from [selectedFileProvider] — the episode on screen — and never
/// from [currentDirectoryProvider]. Since the file browser moved into a
/// drawer, its location is where the reader is looking for what to read next;
/// it says nothing about what they are reading now. Anything that describes
/// the open episode belongs here rather than on the browser's listing.
///
/// A path with no registered novel folder on it falls back to the file's own
/// parent directory. A hand-placed text file is still something the reader is
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
  return p.dirname(selected.path);
});

/// The episodes of the novel the reader has open, in the same order the file
/// browser would show them.
///
/// Deliberately not `directoryContentsProvider`. That one also enumerates
/// subdirectories, resolves novel titles, and — where a `tts_audio.db` exists —
/// opens a per-folder database to read TTS status. Those handles are released
/// when the *browser* leaves a folder, so a second listing opened for the
/// reading folder would sit outside that release path. Listing and sorting is
/// all this needs, and it touches no database.
///
/// Keyed by folder, so moving between episodes of the same novel does not
/// re-list anything.
final readingEpisodesProvider = FutureProvider<List<FileEntry>>((ref) async {
  final folder = ref.watch(readingNovelFolderProvider);
  if (folder == null) return const [];
  return ref.watch(episodesInFolderProvider(folder).future);
});

/// The text files directly inside [folderPath], numeric-prefix sorted.
///
/// The family key is the folder rather than the file, which is what keeps a
/// page turn from costing a directory listing. Public only so that
/// [invalidateEpisodeListings] can name it; read [readingEpisodesProvider].
final episodesInFolderProvider = FutureProvider.family<List<FileEntry>, String>(
  (ref, folderPath) async {
    final service = ref.watch(fileSystemServiceProvider);
    final files = await service.listTextFiles(folderPath);
    return service.sortByNumericPrefix(files);
  },
);

/// Reloads both episode listings: the reader's and the file browser's.
///
/// They are separate providers over the same directories, so anything that can
/// add or remove episodes — a download, a refresh, a TTS operation that writes
/// files — has to invalidate both. Going through one helper is what stops the
/// next call site from remembering only one of them, which would show up as
/// newly fetched episodes that the reader cannot page into.
///
/// [invalidate] is passed as a tear-off from a `WidgetRef`, a provider `Ref`
/// or a container, the way [releaseFolderDbHandles] already takes one, so the
/// widget flows and the provider flows share one implementation.
void invalidateEpisodeListings(void Function(ProviderOrFamily) invalidate) {
  invalidate(directoryContentsProvider);
  invalidate(episodesInFolderProvider);
}
