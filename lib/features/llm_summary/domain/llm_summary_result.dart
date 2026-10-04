import 'dart:convert';

/// Persisted LLM summary row for a `(word, covered_up_to_episode)` snapshot
/// inside a novel's `novel_data.db`. The novel identity is conveyed by which
/// folder's database the row lives in, so no `folder_name` column is stored.
///
/// The `summaryType` (spoiler/no_spoiler) taxonomy that earlier versions used
/// is intentionally absent: range was a runtime concern of the analysis
/// trigger, not a persistence attribute, so snapshots are keyed by the
/// inclusive upper-bound episode number instead.
class WordSummary {
  final int? id;
  final String word;

  /// Inclusive upper bound (file numeric prefix or lexical rank fallback) of
  /// source files that fed this snapshot's LLM analysis.
  final int coveredUpToEpisode;

  final String summary;
  final String? sourceFile;

  /// The reference-source ancestors this snapshot's analysis read, in the
  /// order it resolved them. Empty for a novel without reference sources and
  /// for snapshots saved before reference sources existed.
  final List<SnapshotReferenceSource> referenceSources;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WordSummary({
    this.id,
    required this.word,
    required this.coveredUpToEpisode,
    required this.summary,
    this.sourceFile,
    this.referenceSources = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'word': word,
    'covered_up_to_episode': coveredUpToEpisode,
    'summary': summary,
    'source_file': sourceFile,
    'reference_sources': SnapshotReferenceSource.encodeList(referenceSources),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory WordSummary.fromMap(Map<String, dynamic> map) => WordSummary(
    id: map['id'] as int?,
    word: map['word'] as String,
    coveredUpToEpisode: map['covered_up_to_episode'] as int,
    summary: map['summary'] as String,
    sourceFile: map['source_file'] as String?,
    referenceSources: SnapshotReferenceSource.decodeList(
      map['reference_sources'] as String?,
    ),
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}

/// A reference-source ancestor as a snapshot records it: the folder that
/// identifies it and the title it had when the analysis ran, so the record
/// still reads correctly after the novel is retitled or removed.
class SnapshotReferenceSource {
  const SnapshotReferenceSource({
    required this.folderName,
    required this.title,
  });

  final String folderName;
  final String title;

  /// The column value for [sources]: NULL when there are none, so a novel
  /// without reference sources stores exactly what it stored before.
  static String? encodeList(List<SnapshotReferenceSource> sources) {
    if (sources.isEmpty) return null;
    return jsonEncode([
      for (final s in sources) {'folder_name': s.folderName, 'title': s.title},
    ]);
  }

  /// The list a column value holds. NULL and an empty array both mean none.
  static List<SnapshotReferenceSource> decodeList(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];
    final decoded = jsonDecode(encoded) as List<dynamic>;
    return [
      for (final e in decoded.cast<Map<String, dynamic>>())
        SnapshotReferenceSource(
          folderName: e['folder_name'] as String,
          title: e['title'] as String,
        ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is SnapshotReferenceSource &&
      other.folderName == folderName &&
      other.title == title;

  @override
  int get hashCode => Object.hash(folderName, title);
}
