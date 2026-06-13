import 'package:path/path.dart' as p;

/// Resolves the novel identifier (`novel_id`) for an arbitrary path inside the
/// library.
///
/// The novel id is the **leaf name of the nearest registered novel folder**
/// (`novels.folder_name`). Starting from [libraryRoot], the path is walked from
/// its deepest component upward and the first component that is present in
/// [registeredFolderNames] is returned. This makes the result independent of
/// how deeply the novel is nested under organizational folders.
///
/// Returns `null` when:
/// - [path] is the library root itself,
/// - [path] is outside [libraryRoot], or
/// - no path component is a registered novel folder.
///
/// Unlike `selectedNovelTitleProvider`, this resolver does **not** fall back to
/// the first path segment when no registered ancestor is found: a `novel_id` is
/// a persisted key, and returning an organizational folder name here is exactly
/// the bug (F106) this function exists to prevent.
String? resolveNovelId(
  String libraryRoot,
  String path,
  Set<String> registeredFolderNames,
) {
  if (p.equals(path, libraryRoot)) return null;
  if (!p.isWithin(libraryRoot, path)) return null;

  final relativeParts = p.split(p.relative(path, from: libraryRoot));

  for (final part in relativeParts.reversed) {
    if (registeredFolderNames.contains(part)) return part;
  }
  return null;
}
