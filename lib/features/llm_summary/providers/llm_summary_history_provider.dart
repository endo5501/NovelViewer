import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/first_line_containing.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:path/path.dart' as p;

class LlmSummaryHistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  /// The history belongs to a novel, so it is read from the novel folder the
  /// browser is at — not from whatever directory it happens to show.
  ///
  /// That is also what keeps `novel_data.db` out of folders that are not
  /// novels: opening one creates the file, so treating any non-root directory
  /// as a novel left an organizational folder holding a novel's database.
  @override
  Future<List<HistoryEntry>> build() async {
    final novelFolder = ref.watch(summaryNovelFolderProvider);
    if (novelFolder == null) return const [];

    final repo = await ref.watch(
      llmSummaryRepositoryProvider(novelFolder).future,
    );
    final rows = await repo.findAll();
    return HistoryEntry.mergeRows(rows);
  }

  /// Deletes every snapshot of [word] from [novelFolder].
  ///
  /// The folder is a parameter rather than something resolved here: a
  /// dependency change rebuilds this notifier in place, so anything it held
  /// would be the browser's latest novel, not the one whose list the user is
  /// acting on. The caller holds that list, so the caller holds its folder.
  Future<void> deleteEntry(String word, {required String novelFolder}) async {
    // Checked here as well as by the caller: this opens a per-folder
    // repository, and opening one creates that folder's `novel_data.db`. The
    // folder arrives as a parameter, so trusting it would put the only guard
    // outside the code that does the opening.
    if (!isRegisteredNovelFolder(
      folderPath: novelFolder,
      libraryPath: ref.read(libraryPathProvider),
      novels: ref.read(allNovelsProvider).value,
    )) {
      return;
    }

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

  /// Opens the file a snapshot was taken from, inside [novelFolder].
  ///
  /// A `source_file` is a bare file name recorded against the folder the
  /// episodes were counted in — the novel folder the entry's list was read
  /// from, since analysis only runs while the browser is at one. Passed in
  /// for the same reason as in [deleteEntry].
  Future<void> openEntry(
    HistoryEntry entry, {
    required String novelFolder,
  }) async {
    final directory = novelFolder;

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
