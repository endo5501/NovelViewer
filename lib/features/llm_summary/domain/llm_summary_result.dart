/// Persisted LLM summary row for a `(folder_name, word, covered_up_to_episode)`
/// snapshot. The `summaryType` (spoiler/no_spoiler) taxonomy that earlier
/// versions used is intentionally absent: range was a runtime concern of the
/// analysis trigger, not a persistence attribute, so v5 keys snapshots by the
/// inclusive upper-bound episode number instead.
class WordSummary {
  final int? id;
  final String folderName;
  final String word;

  /// Inclusive upper bound (file numeric prefix or lexical rank fallback) of
  /// source files that fed this snapshot's LLM analysis.
  final int coveredUpToEpisode;

  final String summary;
  final String? sourceFile;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WordSummary({
    this.id,
    required this.folderName,
    required this.word,
    required this.coveredUpToEpisode,
    required this.summary,
    this.sourceFile,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'folder_name': folderName,
        'word': word,
        'covered_up_to_episode': coveredUpToEpisode,
        'summary': summary,
        'source_file': sourceFile,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory WordSummary.fromMap(Map<String, dynamic> map) => WordSummary(
        id: map['id'] as int?,
        folderName: map['folder_name'] as String,
        word: map['word'] as String,
        coveredUpToEpisode: map['covered_up_to_episode'] as int,
        summary: map['summary'] as String,
        sourceFile: map['source_file'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
