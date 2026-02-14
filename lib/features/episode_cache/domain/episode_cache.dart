class EpisodeCache {
  final String url;
  final int episodeIndex;
  final String title;
  final String? lastModified;
  final DateTime downloadedAt;

  const EpisodeCache({
    required this.url,
    required this.episodeIndex,
    required this.title,
    required this.lastModified,
    required this.downloadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'episode_index': episodeIndex,
      'title': title,
      'last_modified': lastModified,
      'downloaded_at': downloadedAt.toIso8601String(),
    };
  }

  factory EpisodeCache.fromMap(Map<String, dynamic> map) {
    return EpisodeCache(
      url: map['url'] as String,
      episodeIndex: map['episode_index'] as int,
      title: map['title'] as String,
      lastModified: map['last_modified'] as String?,
      downloadedAt: DateTime.parse(map['downloaded_at'] as String),
    );
  }
}
