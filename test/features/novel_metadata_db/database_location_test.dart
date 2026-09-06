import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/database_location.dart';

/// Where `novel_metadata.db` lives is a per-platform decision with a different
/// reason behind each branch, and the consequences of getting one wrong are not
/// symmetric: this database holds bookmarks, analysis history and library
/// metadata, none of it reproducible, and it is deliberately opened with
/// `deleteOnFailure: false` so corruption surfaces as a startup error rather
/// than being silently reset.
///
/// The decision is kept here as a pure function so every branch is exercised
/// without `dart:io` — the caller reads `Platform` once and passes the answer
/// in.
void main() {
  group('resolveDatabaseLocation', () {
    test('Windows keeps the database beside the executable', () {
      // Portable ZIP installs must carry their data with them rather than
      // leave it behind in a user profile.
      expect(
        resolveDatabaseLocation(isWindows: true, isIOS: false),
        DatabaseLocation.executableDirectory,
      );
    });

    test('iOS uses application support, not documents', () {
      // `UIFileSharingEnabled` exposes Documents to the Files app. A database
      // the user can delete or edit in a file browser is a database that will
      // eventually fail to open.
      expect(
        resolveDatabaseLocation(isWindows: false, isIOS: true),
        DatabaseLocation.applicationSupport,
      );
    });

    test('macOS and Linux keep the platform default', () {
      expect(
        resolveDatabaseLocation(isWindows: false, isIOS: false),
        DatabaseLocation.platformDefault,
      );
    });
  });
}
