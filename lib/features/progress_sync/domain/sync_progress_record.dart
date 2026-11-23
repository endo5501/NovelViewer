/// One novel's reading progress as it travels between devices.
///
/// [episode] is the effective episode number (`episode-resolution`), which is
/// what identifies the episode across devices: the zero-padding of
/// [fileName] follows the episode count at download time and so differs
/// between devices. [readAt] is when the position last moved, not when the
/// novel was last opened (see design D3).
///
/// [url] and [title] are the novel's work URL and title on the device that
/// published the record, so a device without the novel can offer to download
/// it (`remote-novel-download`). Builds before them published neither, hence
/// both may be null.
class SyncProgressRecord {
  final String novelId;
  final int episode;
  final String fileName;
  final int bodyOffset;
  final String? bodyHash;
  final DateTime readAt;
  final String? url;
  final String? title;

  const SyncProgressRecord({
    required this.novelId,
    required this.episode,
    required this.fileName,
    required this.bodyOffset,
    required this.bodyHash,
    required this.readAt,
    this.url,
    this.title,
  });

  @override
  bool operator ==(Object other) =>
      other is SyncProgressRecord &&
      other.novelId == novelId &&
      other.episode == episode &&
      other.fileName == fileName &&
      other.bodyOffset == bodyOffset &&
      other.bodyHash == bodyHash &&
      other.readAt.isAtSameMomentAs(readAt) &&
      other.url == url &&
      other.title == title;

  @override
  int get hashCode => Object.hash(
    novelId,
    episode,
    fileName,
    bodyOffset,
    bodyHash,
    readAt.microsecondsSinceEpoch,
    url,
    title,
  );

  @override
  String toString() =>
      'SyncProgressRecord($novelId, ep $episode, $fileName@$bodyOffset, '
      '${readAt.toUtc().toIso8601String()})';
}
