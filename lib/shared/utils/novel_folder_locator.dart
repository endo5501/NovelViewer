import 'dart:io';

import 'package:path/path.dart' as p;

/// Finds where in the library each registered novel folder lives.
///
/// `novels` records a folder's name but not its path, and a novel may sit any
/// number of organizing folders deep, so the only way to find one by name is
/// to walk the library. A registered folder found during the walk is recorded
/// and not entered: what is inside a novel is its episodes and its own
/// subfolders, never another novel.
///
/// Returns `folder_name → absolute path` for every registered name found. A
/// registered name with no folder in the library is simply absent, which is
/// how callers learn that a folder has gone missing. An unreadable directory
/// is skipped rather than failing the whole walk.
Map<String, String> locateNovelFolders({
  required String libraryRoot,
  required Set<String> registeredFolderNames,
}) {
  final located = <String, String>{};
  final pending = <Directory>[Directory(libraryRoot)];
  while (pending.isNotEmpty) {
    final dir = pending.removeLast();
    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException {
      continue;
    }
    for (final entry in entries) {
      if (entry is! Directory) continue;
      final name = p.basename(entry.path);
      if (registeredFolderNames.contains(name)) {
        located.putIfAbsent(name, () => entry.path);
      } else {
        pending.add(entry);
      }
    }
  }
  return located;
}
