class ReadingProgress {
  final String novelId;
  final String fileName;
  final DateTime updatedAt;

  const ReadingProgress({
    required this.novelId,
    required this.fileName,
    required this.updatedAt,
  });

  factory ReadingProgress.fromMap(Map<String, dynamic> map) {
    return ReadingProgress(
      novelId: map['novel_id'] as String,
      fileName: map['file_name'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'novel_id': novelId,
      'file_name': fileName,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
