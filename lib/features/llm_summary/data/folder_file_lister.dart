import 'dart:io';

import 'package:path/path.dart' as p;

/// Lists `.txt` file names directly inside [directoryPath], sorted lexically.
/// This is the canonical source of truth for the LLM summary subsystem's
/// "folder file list" — used by:
///   * `LlmSummaryService._filterResultsByUpperBound` (snapshot scope filter)
///   * `analysis_runner.resolveUpperBoundFor{Current,All}` (trigger resolver)
///   * `NovelDatabaseSnapshotResolver.fromLibraryRoot` (v5 migration)
/// All three MUST agree on which files exist and in what order, otherwise a
/// snapshot's `coveredUpToEpisode` will not match what the filter applies.
///
/// Returns an empty list when the directory does not exist or cannot be read.
List<String> listSortedTextFileNames(String directoryPath) {
  try {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return const [];
    final files = dir
        .listSync(followLinks: false)
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where((name) => name.toLowerCase().endsWith('.txt'))
        .toList()
      ..sort();
    return files;
  } catch (_) {
    return const [];
  }
}

/// Extracts the leading numeric prefix of a file name, e.g. `030_chapter.txt`
/// → 30. Returns `null` when no leading digit sequence exists.
int? extractNumericPrefix(String fileName) {
  final match = RegExp(r'^(\d+)').firstMatch(fileName);
  return match != null ? int.parse(match.group(1)!) : null;
}

/// Returns the 1-origin lexical rank of [fileName] within [sortedFiles], or
/// `null` when not found.
int? lexicalRankOf(List<String> sortedFiles, String fileName) {
  if (sortedFiles.isEmpty) return null;
  final i = sortedFiles.indexOf(fileName);
  return i < 0 ? null : i + 1;
}
