import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Returns the temporary directory, creating it on disk if missing.
///
/// On sandboxed macOS/iOS apps, `getTemporaryDirectory()` can return a path
/// whose bundle-id subfolder under `Library/Caches/` has not been
/// materialized yet, so subsequent `File.writeAsBytes()` calls fail with
/// `PathNotFoundException`. This helper closes that gap idempotently.
Future<Directory> ensureTemporaryDirectory({
  Future<Directory> Function() provider = getTemporaryDirectory,
}) async {
  final dir = await provider();
  await dir.create(recursive: true);
  return dir;
}
