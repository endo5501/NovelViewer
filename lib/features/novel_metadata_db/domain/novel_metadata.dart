class NovelMetadata {
  final int? id;
  final String siteType;
  final String novelId;
  final String title;
  final String url;
  final String folderName;
  final int episodeCount;
  final DateTime downloadedAt;
  final DateTime? updatedAt;

  const NovelMetadata({
    this.id,
    required this.siteType,
    required this.novelId,
    required this.title,
    required this.url,
    required this.folderName,
    required this.episodeCount,
    required this.downloadedAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'site_type': siteType,
      'novel_id': novelId,
      'title': title,
      'url': url,
      'folder_name': folderName,
      'episode_count': episodeCount,
      'downloaded_at': downloadedAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory NovelMetadata.fromMap(Map<String, dynamic> map) {
    return NovelMetadata(
      id: map['id'] as int?,
      siteType: map['site_type'] as String,
      novelId: map['novel_id'] as String,
      title: map['title'] as String,
      url: map['url'] as String,
      folderName: map['folder_name'] as String,
      episodeCount: map['episode_count'] as int,
      downloadedAt: DateTime.parse(map['downloaded_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}
