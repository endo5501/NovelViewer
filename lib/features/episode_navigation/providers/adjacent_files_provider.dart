import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

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

/// Derives the previous/next [FileEntry] siblings of the currently selected
/// file using the same numeric-prefix ordering produced by
/// [directoryContentsProvider]. Returns [AdjacentFiles.empty] whenever
/// resolution is impossible (directory not loaded, no selection, selection
/// not in listing, single-file directory at a boundary).
final adjacentFilesProvider = Provider<AdjacentFiles>((ref) {
  final selected = ref.watch(selectedFileProvider);
  if (selected == null) return AdjacentFiles.empty;

  final contents = ref.watch(directoryContentsProvider).value;
  final files = contents?.files;
  if (files == null || files.isEmpty) return AdjacentFiles.empty;

  final idx = files.indexWhere((f) => f.path == selected.path);
  if (idx < 0) return AdjacentFiles.empty;

  return AdjacentFiles(
    prev: idx > 0 ? files[idx - 1] : null,
    next: idx < files.length - 1 ? files[idx + 1] : null,
  );
});
