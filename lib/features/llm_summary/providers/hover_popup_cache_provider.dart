import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';

/// Family key for [hoverPopupCacheProvider]. Two keys with equal `folder` and
/// `word` SHALL be considered identical so the family reuses the same future.
class HoverPopupCacheKey {
  final String folder;
  final String word;

  const HoverPopupCacheKey({required this.folder, required this.word});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoverPopupCacheKey &&
          other.folder == folder &&
          other.word == word;

  @override
  int get hashCode => Object.hash(folder, word);
}

/// Both cached summary rows for one (folder, word) pair, or null when missing.
class WordSummariesByType {
  final WordSummary? noSpoiler;
  final WordSummary? spoiler;

  const WordSummariesByType({this.noSpoiler, this.spoiler});
}

/// Returns the cached no-spoiler and spoiler [WordSummary] rows (if any) for
/// the given (folder, word) pair. Used by the hover popup to display the
/// summary text under the cursor.
final hoverPopupCacheProvider = FutureProvider.family<
    WordSummariesByType, HoverPopupCacheKey>((ref, key) async {
  final repo = await ref.watch(llmSummaryRepositoryProvider.future);
  final noSpoiler = await repo.findSummary(
    folderName: key.folder,
    word: key.word,
    summaryType: SummaryType.noSpoiler,
  );
  final spoiler = await repo.findSummary(
    folderName: key.folder,
    word: key.word,
    summaryType: SummaryType.spoiler,
  );
  return WordSummariesByType(noSpoiler: noSpoiler, spoiler: spoiler);
});
