import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_refresh/domain/refresh_target.dart';
import 'package:novel_viewer/features/text_download/data/sites/generic_web_site.dart';
import 'package:novel_viewer/shared/utils/novel_id_resolver.dart';
import 'package:path/path.dart' as p;

/// The novel that an update started from the app bar would refresh, or null
/// when there is nothing to refresh.
///
/// Resolved from [selectedFileProvider] — the episode on screen — and never
/// from [currentDirectoryProvider]. Now that the file browser lives in a
/// drawer, the reader can take it to the library root or into another novel
/// while the same text stays open; the browser's location is where they are
/// looking for their next episode, not what they are reading.
///
/// Null means the app bar's button offers a new download instead, so every
/// case that cannot be refreshed belongs here rather than in an error the
/// reader only discovers after pressing:
/// - nothing is on screen,
/// - the path holds no registered novel folder (an organizational folder, a
///   stray text file),
/// - the novel is a generic-web collection: a curated set of articles that is
///   collected one article at a time, not re-fetched as a whole.
///
/// The novel list is read synchronously, so a refresh target appears only once
/// it has loaded. That settles in a microtask at startup, and resolving to "no
/// registered novels" in the meantime gives the download button — the safe one
/// of the two, since it opens a dialog rather than starting a transfer.
final refreshTargetProvider = Provider<RefreshTarget?>((ref) {
  final selected = ref.watch(selectedFileProvider);
  if (selected == null) return null;

  final libraryPath = ref.watch(libraryPathProvider);
  if (libraryPath == null) return null;

  final novels = ref.watch(allNovelsProvider).value ?? const <NovelMetadata>[];
  if (novels.isEmpty) return null;

  // The shared rule (also used to key reading progress and the per-folder
  // databases), so the target is the same novel those features would name,
  // however deeply it is nested under organizational folders.
  final folderPath = resolveNovelFolderPath(libraryPath, selected.path, {
    for (final novel in novels) novel.folderName,
  });
  if (folderPath == null) return null;

  final folderName = p.basename(folderPath);
  final metadata = novels.where((n) => n.folderName == folderName).firstOrNull;
  if (metadata == null) return null;
  if (metadata.siteType == GenericWebSite.siteTypeId) return null;

  return RefreshTarget(
    folderName: folderName,
    parentPath: p.dirname(folderPath),
    title: metadata.title,
  );
});
