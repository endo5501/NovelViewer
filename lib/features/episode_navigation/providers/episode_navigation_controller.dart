import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/episode_navigation/domain/file_entry_start_intent.dart';
import 'package:novel_viewer/features/episode_navigation/providers/adjacent_files_provider.dart';
import 'package:novel_viewer/features/episode_navigation/providers/pending_file_entry_intent_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

/// Coordinates file navigation that requires both an intent hint (fromStart
/// or fromEnd) and a `selectedFileProvider` swap to happen atomically from
/// the viewer's perspective: the intent MUST be visible the instant the
/// viewer observes the new selected file.
class EpisodeNavigationController {
  EpisodeNavigationController(this._ref);

  final Ref _ref;

  /// Switches the viewer to the next adjacent file (if any). Sets
  /// [FileEntryStartIntent.fromStart] so the new file opens from the
  /// beginning. No-op if there is no next file.
  void navigateToNext() => _navigate(_ref.read(adjacentFilesProvider).next,
      FileEntryStartIntent.fromStart);

  /// Switches the viewer to the previous adjacent file (if any). Sets
  /// [FileEntryStartIntent.fromEnd] so the new file opens from its tail —
  /// this matches "reading backward" continuity. No-op if no previous file.
  void navigateToPrevious() => _navigate(_ref.read(adjacentFilesProvider).prev,
      FileEntryStartIntent.fromEnd);

  void _navigate(FileEntry? target, FileEntryStartIntent intent) {
    if (target == null) return;
    // Intent must land before the selection changes so the viewer's listener
    // sees the hint synchronously on the new build.
    _ref.read(pendingFileEntryIntentProvider.notifier).set(intent);
    _ref.read(selectedFileProvider.notifier).selectFile(target);
  }
}

final episodeNavigationControllerProvider =
    Provider<EpisodeNavigationController>(
  EpisodeNavigationController.new,
);
