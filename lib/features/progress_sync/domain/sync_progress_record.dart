/// One novel's reading progress as it travels between devices.
///
/// [episode] is the effective episode number (`episode-resolution`), which is
/// what identifies the episode across devices: the zero-padding of
/// [fileName] follows the episode count at download time and so differs
/// between devices. [readAt] is when the position last moved, not when the
/// novel was last opened (see design D3).
class SyncProgressRecord {
  final String novelId;
  final int episode;
  final String fileName;
  final int bodyOffset;
  final String? bodyHash;
  final DateTime readAt;

  const SyncProgressRecord({
    required this.novelId,
    required this.episode,
    required this.fileName,
    required this.bodyOffset,
    required this.bodyHash,
    required this.readAt,
  });

  @override
  bool operator ==(Object other) =>
      other is SyncProgressRecord &&
      other.novelId == novelId &&
      other.episode == episode &&
      other.fileName == fileName &&
      other.bodyOffset == bodyOffset &&
      other.bodyHash == bodyHash &&
      other.readAt.isAtSameMomentAs(readAt);

  @override
  int get hashCode => Object.hash(
    novelId,
    episode,
    fileName,
    bodyOffset,
    bodyHash,
    readAt.microsecondsSinceEpoch,
  );

  @override
  String toString() =>
      'SyncProgressRecord($novelId, ep $episode, $fileName@$bodyOffset, '
      '${readAt.toUtc().toIso8601String()})';
}
