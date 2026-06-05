// Shared helpers for sanitising and validating file/folder names so the
// download pipeline and the file browser apply the same rules.

/// Characters that are not permitted in file or folder names on the supported
/// platforms (Windows is the strictest, so its reserved set is used).
final RegExp invalidFileNameChars = RegExp(r'[\\/:*?"<>|]');

final RegExp _multipleSpaces = RegExp(r'\s+');

/// Sanitises [name] for use as a file or folder name by replacing invalid
/// characters with `_`, collapsing runs of whitespace, and trimming.
String safeName(String name) {
  return name
      .replaceAll(invalidFileNameChars, '_')
      .replaceAll(_multipleSpaces, ' ')
      .trim();
}

/// Returns true when [name] is a usable folder name: non-blank and free of
/// characters that are invalid on the supported platforms.
bool isValidFolderName(String name) {
  if (name.trim().isEmpty) return false;
  if (invalidFileNameChars.hasMatch(name)) return false;
  return true;
}
