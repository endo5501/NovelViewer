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
  /// The history belongs to a novel, so it is read from the novel folder that
  /// owns the browser's current directory — not from the directory itself.
  ///
  /// Resolving it is what keeps `novel_data.db` out of folders that are not
  /// novels: opening one creates the file, so treating any non-root directory
  /// as a novel left an organizational folder holding a novel's database. The
  /// bookmark panel, which reads the same file, has always resolved it this
  /// way; this is the same rule, not a second one.
  @override
  Future<List<HistoryEntry>> build() async {
    final novelFolder = await ref.watch(currentNovelFolderPathProvider.future);
    if (novelFolder == null) return const [];

    final repo = await ref.watch(
      llmSummaryRepositoryProvider(novelFolder).future,
    );
    final rows = await repo.findAll();
    return HistoryEntry.mergeRows(rows);
  }

  Future<void> deleteEntry(String word) async {
    final novelFolder = await ref.read(currentNovelFolderPathProvider.future);
    if (novelFolder == null) return;

    final repo = await ref.read(
      llmSummaryRepositoryProvider(novelFolder).future,
    );
    final factCache = await ref.read(
      factCacheRepositoryProvider(novelFolder).future,
    );

    await repo.deleteAllForWord(word: word);
    // Cascade the per-file fact cache so deleting a word's summaries also
    // drops its cached extraction (see llm-summary-fact-cache "Cascade
    // cleanup").
    await factCache.deleteAllForWord(word: word);

    ref.invalidateSelf();
  }

  /// Opens the file a snapshot was taken from.
  ///
  /// The folder here is the browser's current directory, not the novel folder
  /// the database came from. A `source_file` is a bare file name recorded
  /// against the folder the episodes were read from, so resolving it against
  /// the novel folder would look for the file one level up from where it is.
  /// The two are the same folder in every layout the application can produce.
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
