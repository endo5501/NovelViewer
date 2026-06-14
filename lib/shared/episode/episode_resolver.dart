import 'dart:io';

import 'package:path/path.dart' as p;

/// Single source of truth for deriving an "effective episode number" from a
/// novel's text files and for listing those files in a stable order.
///
/// The effective episode rule is: the file name's leading numeric prefix when
/// present, otherwise its 1-origin lexical rank within the folder's `.txt`
/// listing. The LLM summary subsystem relies on every consumer agreeing on
/// this rule and on the folder listing — when they drift, a snapshot's
/// `coveredUpToEpisode` no longer matches what the scope filter applies, which
/// leaks content from chapters past the reader's current position.
///
/// All functions here are pure with respect to their inputs (only
/// [listSortedTextFileNames] touches the filesystem) and take no feature types,
/// so this module can live below feature layers and be consumed by both
/// `novel_metadata_db` and `llm_summary`.

/// Lists `.txt` file names directly inside [directoryPath], sorted lexically
/// (ascending). The extension match is case-insensitive. Returns an empty list
/// when the directory does not exist or cannot be read.
///
/// [onError] is invoked (best-effort) when listing throws — e.g. a permission
/// error — so callers that want a diagnostic trace can log it while still
/// receiving the empty-list fallback. A missing directory returns empty
/// without invoking [onError].
List<String> listSortedTextFileNames(
  String directoryPath, {
  void Function(Object error, StackTrace stack)? onError,
}) {
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
  } catch (e, st) {
    onError?.call(e, st);
    return const [];
  }
}

/// Extracts the leading numeric prefix of a file name, e.g. `030_chapter.txt`
/// → 30. Returns `null` when no leading digit sequence exists, or when the
/// digit run overflows a 64-bit int (a pathological name degrades to "no
/// numeric prefix" rather than throwing).
int? extractNumericPrefix(String fileName) {
  final match = RegExp(r'^(\d+)').firstMatch(fileName);
  return match != null ? int.tryParse(match.group(1)!) : null;
}

/// Returns the 1-origin lexical rank of [fileName] within [sortedFiles], or
/// `null` when not found (including when [sortedFiles] is empty).
int? lexicalRankOf(List<String> sortedFiles, String fileName) {
  if (sortedFiles.isEmpty) return null;
  final i = sortedFiles.indexOf(fileName);
  return i < 0 ? null : i + 1;
}

/// The effective episode number of [fileName] without a fallback: the numeric
/// prefix when present, otherwise the 1-origin lexical rank within
/// [folderFiles], otherwise `null`.
///
/// Used by the scope filter, where a file absent from the folder listing must
/// be excluded (null) rather than coerced to a low episode number.
int? effectiveEpisodeOrNull(String fileName, List<String> folderFiles) {
  final prefix = extractNumericPrefix(fileName);
  if (prefix != null) return prefix;
  return lexicalRankOf(folderFiles, fileName);
}

/// Resolves the "解析開始(ネタバレなし)" upper bound for the currently-viewed
/// file: the numeric prefix when present, otherwise the 1-origin lexical rank
/// within the folder, otherwise a pessimistic fallback of `1`.
///
/// [folderFiles] is a thunk so callers avoid listing the directory when the
/// file already carries a numeric prefix.
int resolveCurrentFileEpisode({
  required String fileName,
  required List<String> Function() folderFiles,
}) {
  final prefix = extractNumericPrefix(fileName);
  if (prefix != null) return prefix;
  final files = folderFiles();
  if (files.isEmpty) return 1;
  return lexicalRankOf(files, fileName) ?? 1;
}

/// Resolves the "解析開始(ネタバレあり)" upper bound that captures every file
/// in [folderFiles]: `max(highest numeric prefix, total .txt count)` so that a
/// folder mixing numbered files with prefix-less files still includes the
/// prefix-less files via the count-based bound. Returns `1` when empty.
int resolveUpperBoundForAllFiles(List<String> folderFiles) {
  if (folderFiles.isEmpty) return 1;
  int? maxPrefix;
  for (final name in folderFiles) {
    final prefix = extractNumericPrefix(name);
    if (prefix != null && (maxPrefix == null || prefix > maxPrefix)) {
      maxPrefix = prefix;
    }
  }
  final lengthBased = folderFiles.length;
  if (maxPrefix == null) return lengthBased;
  return maxPrefix > lengthBased ? maxPrefix : lengthBased;
}

/// Resolves the file a spoiler-mode (全話) snapshot should link back to:
/// the highest-prefix file when any prefix exists, otherwise the last lexical
/// file. Returns `null` when [folderFiles] is empty.
String? resolveSourceFileForAllFiles(List<String> folderFiles) {
  if (folderFiles.isEmpty) return null;
  String? candidate;
  int? candidatePrefix;
  for (final name in folderFiles) {
    final prefix = extractNumericPrefix(name);
    if (prefix != null) {
      if (candidatePrefix == null || prefix > candidatePrefix) {
        candidate = name;
        candidatePrefix = prefix;
      }
    }
  }
  return candidate ?? folderFiles.last;
}
