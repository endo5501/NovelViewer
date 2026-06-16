/// Parses the leading episode number from a downloaded episode file name.
///
/// Downloaded files are named `{1-based episode number}_{title}.txt` by
/// [formatEpisodeFileName], so the leading digits are the episode number
/// itself. Returns 0 when the name does not start with a number (defensive:
/// the badge then renders as "unread" rather than crashing).
int parseEpisodeNumber(String fileName) {
  final match = RegExp(r'^(\d+)').firstMatch(fileName);
  if (match == null) return 0;
  return int.parse(match.group(1)!);
}

/// Reading progress shown on a novel folder tile in the file browser.
///
/// [read] is the "current position" — the episode number of the last opened
/// file (0 when the novel has no `reading_progress` row, i.e. unread).
/// [total] is the novel's `episode_count`. Both are derived purely from the
/// global `novel_metadata.db`; no folder DB or filesystem walk is involved.
class ReadingProgressBadge {
  final int read;
  final int total;

  const ReadingProgressBadge({required this.read, required this.total});

  /// Builds a badge from a novel's `episode_count` and its stored
  /// `reading_progress.file_name` (null when unread).
  factory ReadingProgressBadge.from({
    required int episodeCount,
    required String? fileName,
  }) {
    return ReadingProgressBadge(
      read: fileName == null ? 0 : parseEpisodeNumber(fileName),
      total: episodeCount,
    );
  }

  /// Progress ratio in [0.0, 1.0] for the progress bar. Guards against a zero
  /// total (no division by zero) and clamps when `read` exceeds `total`.
  double get fraction {
    if (total <= 0) return 0.0;
    return (read / total).clamp(0.0, 1.0);
  }
}
