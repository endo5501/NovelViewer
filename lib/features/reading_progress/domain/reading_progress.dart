class ReadingProgress {
  final String novelId;
  final String fileName;
  final DateTime updatedAt;
  final int bodyOffset;
  final String? bodyHash;

  const ReadingProgress({
    required this.novelId,
    required this.fileName,
    required this.updatedAt,
    this.bodyOffset = 0,
    this.bodyHash,
  });

  factory ReadingProgress.fromMap(Map<String, dynamic> map) {
    return ReadingProgress(
      novelId: map['novel_id'] as String,
      fileName: map['file_name'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
      bodyOffset: map['body_offset'] as int? ?? 0,
      bodyHash: map['body_hash'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'novel_id': novelId,
      'file_name': fileName,
      'updated_at': updatedAt.toIso8601String(),
      'body_offset': bodyOffset,
      'body_hash': bodyHash,
    };
  }
}
