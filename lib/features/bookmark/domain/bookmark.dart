class Bookmark {
  final int? id;
  final String novelId;
  final String fileName;
  final String filePath;
  final int? lineNumber;
  final DateTime createdAt;

  const Bookmark({
    this.id,
    required this.novelId,
    required this.fileName,
    required this.filePath,
    this.lineNumber,
    required this.createdAt,
  });

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as int?,
      novelId: map['novel_id'] as String,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      lineNumber: map['line_number'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'novel_id': novelId,
      'file_name': fileName,
      'file_path': filePath,
      'line_number': lineNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
