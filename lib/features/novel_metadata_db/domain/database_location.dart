/// Where the global `novel_metadata.db` file belongs on a given platform.
enum DatabaseLocation {
  /// Beside the running executable. Windows ships as a portable ZIP as well as
  /// an installer, and a portable copy must carry its data with it.
  executableDirectory,

  /// The app's private support directory. Used where the documents directory
  /// is visible to the user — on iOS `UIFileSharingEnabled` exposes Documents
  /// to the Files app, and this database must not be sitting there next to the
  /// novel library where it can be deleted or edited.
  applicationSupport,

  /// Whatever the SQLite plugin considers the default database directory.
  platformDefault,
}

/// Decides where the database directory is, given the platform.
///
/// Kept free of `dart:io` so every branch is testable; the caller reads
/// `Platform` and passes the answers in.
DatabaseLocation resolveDatabaseLocation({
  required bool isWindows,
  required bool isIOS,
}) {
  if (isWindows) return DatabaseLocation.executableDirectory;
  if (isIOS) return DatabaseLocation.applicationSupport;
  return DatabaseLocation.platformDefault;
}
