import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';

typedef HoverPopupCacheKey = ({String folderPath, String word});

/// Cached snapshots for `(folderPath, word)`, sorted ascending by
/// `coveredUpToEpisode`. The hover popup feeds this list into the snapshot
/// navigator and the future-warning rule. `folderPath` is the novel folder's
/// absolute path, used to resolve its per-folder `novel_data.db`.
final hoverPopupCacheProvider =
    FutureProvider.family<List<WordSummary>, HoverPopupCacheKey>(
        (ref, key) async {
  final repo =
      await ref.watch(llmSummaryRepositoryProvider(key.folderPath).future);
  return repo.findSnapshotsForWord(word: key.word);
});

/// Selects the default snapshot to display in the hover popup given a
/// snapshot list and the current file's effective episode number.
/// Returns `null` when [snapshots] is empty.
WordSummary? chooseDefaultSnapshot(
  List<WordSummary> snapshots,
  int currentEpisode,
) {
  if (snapshots.isEmpty) return null;
  WordSummary? best;
  for (final s in snapshots) {
    if (s.coveredUpToEpisode <= currentEpisode) {
      if (best == null || s.coveredUpToEpisode > best.coveredUpToEpisode) {
        best = s;
      }
    }
  }
  if (best != null) return best;
  // No "past" snapshot exists — return the earliest future snapshot. Caller
  // is responsible for showing the future-warning icon based on
  // `coveredUpToEpisode > currentEpisode`.
  return snapshots.first;
}
