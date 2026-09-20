/// The novel an update would be applied to, resolved from the episode the
/// text viewer is showing.
///
/// [folderName] and [parentPath] are exactly what `DownloadNotifier.refreshNovel`
/// takes: the novel folder's leaf name, and the directory it physically sits in
/// so the re-download overwrites it in place rather than at the library root.
/// [title] labels the progress dialog.
class RefreshTarget {
  const RefreshTarget({
    required this.folderName,
    required this.parentPath,
    required this.title,
  });

  final String folderName;
  final String parentPath;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is RefreshTarget &&
      other.folderName == folderName &&
      other.parentPath == parentPath &&
      other.title == title;

  @override
  int get hashCode => Object.hash(folderName, parentPath, title);

  @override
  String toString() =>
      'RefreshTarget(folderName: $folderName, parentPath: $parentPath, '
      'title: $title)';
}
