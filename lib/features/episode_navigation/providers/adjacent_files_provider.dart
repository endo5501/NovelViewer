import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/reading_context/providers/reading_context_providers.dart';

/// Snapshot of the files immediately before and after the currently selected
/// file within the active directory listing. Either side is `null` when no
/// adjacent file exists (boundary, no selection, or selection not present in
/// the listing).
class AdjacentFiles {
  const AdjacentFiles({required this.prev, required this.next});

  final FileEntry? prev;
  final FileEntry? next;

  static const empty = AdjacentFiles(prev: null, next: null);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AdjacentFiles && other.prev == prev && other.next == next);

  @override
  int get hashCode => Object.hash(prev, next);
}

/// Derives the previous/next [FileEntry] siblings of the open episode from the
/// reading context's own episode listing, in the numeric-prefix order the file
/// browser uses. Returns [AdjacentFiles.empty] whenever resolution is
/// impossible (listing not loaded, nothing open, the open file is not in the
/// listing, single-episode novel at a boundary).
///
/// Not the browser's listing: the drawer moves independently of the text, so
/// reading it here meant that looking for the next novel to read silently
/// disabled paging on the one in hand. This provider is the only source of
/// next/previous, and both viewers' page turns go through it.
final adjacentFilesProvider = Provider<AdjacentFiles>((ref) {
  final selected = ref.watch(selectedFileProvider);
  if (selected == null) return AdjacentFiles.empty;

  final files = ref.watch(readingEpisodesProvider).value;
  if (files == null || files.isEmpty) return AdjacentFiles.empty;

  final idx = files.indexWhere((f) => f.path == selected.path);
  if (idx < 0) return AdjacentFiles.empty;

  return AdjacentFiles(
    prev: idx > 0 ? files[idx - 1] : null,
    next: idx < files.length - 1 ? files[idx + 1] : null,
  );
});
