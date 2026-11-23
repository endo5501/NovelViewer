import 'device_progress.dart';

/// The novels to offer for download (remote-novel-download): records received
/// from other devices for novels not in [registeredFolderNames], whose url
/// [urlMatches] accepts as leading to that novel. One per novel, the newest
/// read of those, newest first.
List<RemoteProgress> buildRemoteNovelCandidates({
  required List<RemoteProgress> remote,
  required Set<String> registeredFolderNames,
  required bool Function(String url, String novelId) urlMatches,
}) {
  final newest = <String, RemoteProgress>{};
  for (final entry in remote) {
    final record = entry.record;
    if (registeredFolderNames.contains(record.novelId)) continue;
    final url = record.url;
    if (url == null || !urlMatches(url, record.novelId)) continue;
    final current = newest[record.novelId];
    if (current == null || record.readAt.isAfter(current.record.readAt)) {
      newest[record.novelId] = entry;
    }
  }
  return newest.values.toList()
    ..sort((a, b) => b.record.readAt.compareTo(a.record.readAt));
}
