/// Thrown when a database connection is requested while the owning wrapper is
/// in the middle of `close()`.
///
/// The gate deliberately surfaces this instead of transparently re-opening: a
/// request that lands during close almost always means a caller is racing a
/// folder move/rename/delete, and re-opening would re-lock the file the close
/// is trying to release. Callers obtain a fresh handle through the registry
/// after the close completes, not by retrying the getter mid-close.
class DatabaseClosingException implements Exception {
  const DatabaseClosingException();

  @override
  String toString() =>
      'DatabaseClosingException: database connection is closing';
}
