import 'package:path/path.dart' as p;

/// Computes where the file browser's current directory should point after the
/// folder at [sourcePath] is moved to [newSourcePath].
///
/// Returns the rebased path when [currentDir] is the moved folder or one of its
/// descendants, so the browser keeps showing the same content at its new
/// location. Returns null when the current directory is unrelated (or null),
/// meaning no follow is required.
String? followedCurrentDirectory({
  required String? currentDir,
  required String sourcePath,
  required String newSourcePath,
}) {
  if (currentDir == null) return null;
  if (p.equals(currentDir, sourcePath)) return newSourcePath;
  if (p.isWithin(sourcePath, currentDir)) {
    final relative = p.relative(currentDir, from: sourcePath);
    return p.join(newSourcePath, relative);
  }
  return null;
}
