enum SummaryType {
  spoiler,
  noSpoiler;

  String toDbString() => switch (this) {
        SummaryType.spoiler => 'spoiler',
        SummaryType.noSpoiler => 'no_spoiler',
      };

  static SummaryType fromDbString(String value) => switch (value) {
        'spoiler' => SummaryType.spoiler,
        'no_spoiler' => SummaryType.noSpoiler,
        _ => throw ArgumentError('Unknown summary type: $value'),
      };
}

class WordSummary {
  final int? id;
  final String folderName;
  final String word;
  final SummaryType summaryType;
  final String summary;
  final String? sourceFile;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WordSummary({
    this.id,
    required this.folderName,
    required this.word,
    required this.summaryType,
    required this.summary,
    this.sourceFile,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'folder_name': folderName,
        'word': word,
        'summary_type': summaryType.toDbString(),
        'summary': summary,
        'source_file': sourceFile,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory WordSummary.fromMap(Map<String, dynamic> map) => WordSummary(
        id: map['id'] as int?,
        folderName: map['folder_name'] as String,
        word: map['word'] as String,
        summaryType: SummaryType.fromDbString(map['summary_type'] as String),
        summary: map['summary'] as String,
        sourceFile: map['source_file'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
