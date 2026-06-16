import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/first_line_containing.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:path/path.dart' as p;

class LlmSummaryHistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  @override
  Future<List<HistoryEntry>> build() async {
    final directory = ref.watch(currentDirectoryProvider);
    if (directory == null) return const [];

    final repo = await ref.watch(llmSummaryRepositoryProvider(directory).future);
    final rows = await repo.findAll();
    return HistoryEntry.mergeRows(rows);
  }

  Future<void> deleteEntry(String word) async {
    final directory = ref.read(currentDirectoryProvider);
    if (directory == null) return;

    final repo = await ref.read(llmSummaryRepositoryProvider(directory).future);
    final factCache =
        await ref.read(factCacheRepositoryProvider(directory).future);

    await repo.deleteAllForWord(word: word);
    // Cascade the per-file fact cache so deleting a word's summaries also
    // drops its cached extraction (see llm-summary-fact-cache "Cascade
    // cleanup").
    await factCache.deleteAllForWord(word: word);

    ref.invalidateSelf();
  }

  Future<void> openEntry(HistoryEntry entry) async {
    final directory = ref.read(currentDirectoryProvider);
    if (directory == null) return;

    // Try every snapshot's source_file (largest episode first, since that's
    // the canonical "primary" jump target per spec) and fall through to the
    // next-largest when a file is missing on disk. This makes the jump
    // resilient to source files that were since renamed/deleted out-of-band
    // — without this loop, a stale source_file on the largest-episode
    // snapshot would cause the click to silently no-op even though other
    // snapshots for the same word still point at existing files.
    //
    // `LinkedHashSet` deduplicates while preserving largest-first order:
    // when multiple snapshots share the same source_file (e.g., the user
    // re-analyzed at the same upper bound), avoid retrying the same I/O.
    final candidates = <String>{
      for (var i = entry.snapshots.length - 1; i >= 0; i--)
        if (entry.snapshots[i].sourceFile != null)
          entry.snapshots[i].sourceFile!,
    };
    if (candidates.isEmpty) return;

    for (final sourceFile in candidates) {
      final filePath = p.join(directory, sourceFile);
      final file = File(filePath);
      final String content;
      try {
        content = await file.readAsString();
      } catch (_) {
        // File missing or unreadable — try the next snapshot's source.
        continue;
      }

      ref
          .read(selectedFileProvider.notifier)
          .selectFile(FileEntry(name: sourceFile, path: filePath));

      final lineNumber = findFirstLineContaining1Indexed(content, entry.word);
      if (lineNumber != null) {
        ref.read(bookmarkJumpLineProvider.notifier).jump(lineNumber);
      }
      return;
    }
  }
}

final llmSummaryHistoryProvider =
    AsyncNotifierProvider<LlmSummaryHistoryNotifier, List<HistoryEntry>>(
  LlmSummaryHistoryNotifier.new,
);
