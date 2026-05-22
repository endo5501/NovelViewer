import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/first_line_containing.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:path/path.dart' as p;

class LlmSummaryHistoryNotifier
    extends AsyncNotifier<List<HistoryEntry>> {
  @override
  Future<List<HistoryEntry>> build() async {
    final directory = ref.watch(currentDirectoryProvider);
    if (directory == null) return const [];

    final folderName = p.basename(directory);
    final repo = await ref.watch(llmSummaryRepositoryProvider.future);
    final rows = await repo.findAllByFolder(folderName);
    return HistoryEntry.mergeRows(rows);
  }

  Future<void> deleteEntry(String word) async {
    final directory = ref.read(currentDirectoryProvider);
    if (directory == null) return;

    final folderName = p.basename(directory);
    final repo = await ref.read(llmSummaryRepositoryProvider.future);

    await repo.deleteSummary(
      folderName: folderName,
      word: word,
      summaryType: SummaryType.noSpoiler,
    );
    await repo.deleteSummary(
      folderName: folderName,
      word: word,
      summaryType: SummaryType.spoiler,
    );

    ref.invalidateSelf();
  }

  Future<void> openEntry(HistoryEntry entry) async {
    final directory = ref.read(currentDirectoryProvider);
    final sourceFile = entry.sourceFile;
    if (directory == null || sourceFile == null) return;

    final filePath = p.join(directory, sourceFile);
    final file = File(filePath);
    final String content;
    try {
      content = await file.readAsString();
    } on FileSystemException {
      return;
    }

    ref
        .read(selectedFileProvider.notifier)
        .selectFile(FileEntry(name: sourceFile, path: filePath));

    final lineNumber = findFirstLineContaining1Indexed(content, entry.word);
    if (lineNumber != null) {
      ref.read(bookmarkJumpLineProvider.notifier).jump(lineNumber);
    }
  }
}

final llmSummaryHistoryProvider =
    AsyncNotifierProvider<LlmSummaryHistoryNotifier, List<HistoryEntry>>(
  LlmSummaryHistoryNotifier.new,
);
