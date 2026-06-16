/// A bookmark inside a novel's `novel_data.db`. The novel identity is conveyed
/// by which folder's database the row lives in, so no `novel_id` column is
/// stored. Identity within a novel is `(file_name, line_number)`.
class Bookmark {
  final int? id;
  final String fileName;
  final int? lineNumber;
  final DateTime createdAt;

  const Bookmark({
    this.id,
    required this.fileName,
    this.lineNumber,
    required this.createdAt,
  });

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as int?,
      fileName: map['file_name'] as String,
      lineNumber: map['line_number'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'file_name': fileName,
      'line_number': lineNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
