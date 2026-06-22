import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';

typedef HistoryDetailKey = ({String folderPath, String word});

/// Cached Stage-1 facts for `(folderPath, word)`. The read-only detail dialog's
/// "事実" tab feeds this list into a per-file list; invalid rows (sentinel
/// `content_hash`) are kept in the list and rendered greyed-out rather than
/// dropped. Display ordering (by `file_name` ascending) is the tab's
/// responsibility, so it is not imposed here. `folderPath` is the novel
/// folder's absolute path, used to resolve its per-folder `novel_data.db`.
///
/// `autoDispose` because this is parameterized by user data (the word) and is
/// only watched while the detail dialog is open; without it every inspected
/// word would leave a cached entry alive for the app's lifetime.
final historyDetailFactsProvider =
    FutureProvider.autoDispose.family<List<FactCacheEntry>, HistoryDetailKey>(
        (ref, key) async {
  final repo =
      await ref.watch(factCacheRepositoryProvider(key.folderPath).future);
  return repo.findForWord(word: key.word);
});
