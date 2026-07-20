import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry_provider.dart';

/// Closes every per-folder database handle [container] opened, then disposes
/// the container.
///
/// `container.dispose()` alone is not enough: the registry releases its handles
/// from `ref.onDispose(registry.disposeAll)`, and Riverpod does not await the
/// Future an onDispose callback returns. The SQLite close is therefore still in
/// flight when `dispose()` returns, and a test that deletes its temp directory
/// right after hits `PathAccessException ... errno = 32` on Windows (POSIX
/// happily unlinks open files, which is why this only ever fails on Windows CI).
Future<void> disposeContainerWithDatabases(ProviderContainer container) async {
  await container.read(perFolderDbRegistryProvider).disposeAll();
  container.dispose();
}

/// Registers a teardown that awaits the per-folder database closes before
/// disposing [container]. Use this instead of `addTearDown(container.dispose)`
/// in any test that opens a registry-owned database inside a temp directory it
/// later deletes.
void addDbContainerTearDown(ProviderContainer container) {
  addTearDown(() => disposeContainerWithDatabases(container));
}
