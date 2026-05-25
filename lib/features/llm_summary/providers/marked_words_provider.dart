import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';

/// Maps each markable word (2+ characters) in the active folder to its
/// [MarkStyle]. v5 uses a uniform `solid` style for every cached word
/// regardless of how many snapshots exist or where they fall relative to
/// the current page — the per-snapshot information is conveyed inside the
/// hover popup, not on the mark itself. Returns an empty map while history
/// is loading or errored.
final markedWordsProvider = Provider<Map<String, MarkStyle>>((ref) {
  final historyAsync = ref.watch(llmSummaryHistoryProvider);
  final entries = historyAsync.value ?? const [];
  return {
    for (final e in entries)
      if (e.word.length >= 2) e.word: MarkStyle.solid,
  };
});
