import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';

typedef HoverPopupCacheKey = ({String folder, String word});

class WordSummariesByType {
  final WordSummary? noSpoiler;
  final WordSummary? spoiler;

  const WordSummariesByType({this.noSpoiler, this.spoiler});
}

final hoverPopupCacheProvider =
    FutureProvider.family<WordSummariesByType, HoverPopupCacheKey>(
        (ref, key) async {
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
