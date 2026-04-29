import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';

/// Heuristic: does this open failure look like on-disk corruption rather
/// than a transient/locked/permission issue? Only corruption justifies
/// deleting the file under `deleteOnFailure: true`.
bool _looksLikeCorruption(Object error) {
  final s = error.toString().toLowerCase();
  return s.contains('malformed') ||
      s.contains('file is not a database') ||
      s.contains('database disk image is malformed') ||
      s.contains('database is corrupt') ||
      s.contains('not a database');
}

/// Opens a SQLite database and applies the caller-specified recovery policy
/// when the open fails.
///
/// - `deleteOnFailure: true` — if the open throws and the failure looks like
///   on-disk corruption, log a WARNING (when a `logger` is supplied), delete
///   the database file (including `-wal`/`-shm` sidecars via
///   `deleteDatabase`), and reopen it via `onCreate`. Transient failures
///   (locks, permissions) are still rethrown so we don't destroy a healthy
///   DB that just happens to be busy. Appropriate for databases whose
///   contents are reproducible from external state (TTS audio, episode
///   cache, dictionary).
/// - `deleteOnFailure: false` — if the open throws, log a WARNING and rethrow
///   the original exception. The file is preserved on disk. Appropriate for
///   databases storing non-reproducible user data (novel metadata,
///   bookmarks).
Future<Database> openOrResetDatabase({
  required String path,
  required int version,
  required Future<void> Function(Database db, int version) onCreate,
  Future<void> Function(Database db, int oldVersion, int newVersion)? onUpgrade,
  Future<void> Function(Database db)? onConfigure,
  bool deleteOnFailure = false,
  Logger? logger,
}) async {
  try {
    return await openDatabase(
      path,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onConfigure: onConfigure,
    );
  } catch (e, st) {
    logger?.warning('Failed to open database at $path', e, st);
    if (!deleteOnFailure || !_looksLikeCorruption(e)) rethrow;
    logger?.warning(
        'Resetting corrupt database at $path (will recreate via onCreate)');
    await deleteDatabase(path);
    return openDatabase(
      path,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onConfigure: onConfigure,
    );
  }
}
