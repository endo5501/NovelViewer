import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'per_folder_db_registry.dart';

/// The single owner of per-folder database handles. Per-folder DB providers
/// are thin views that read their handle from this registry; folder mutation
/// flows release handles via `registry.closeAll(folder)`.
final perFolderDbRegistryProvider = Provider<PerFolderDbRegistry>((ref) {
  final registry = PerFolderDbRegistry();
  ref.onDispose(registry.disposeAll);
  return registry;
});
