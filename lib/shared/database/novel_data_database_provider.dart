import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'novel_data_database.dart';
import 'per_folder_db_registry_provider.dart';

/// Per-folder `NovelDataDatabase`, a thin view over [perFolderDbRegistryProvider].
///
/// Like the TTS/episode-cache providers, the registry owns the handle's
/// open/close lifecycle (keyed by the normalized folder path) and releases it
/// via `closeAll(folder)`. This provider never closes the handle in
/// `onDispose`: ownership lives in one place so a new consumer cannot
/// reintroduce the Windows file-lock bug.
final novelDataDatabaseProvider =
    Provider.family<NovelDataDatabase, String>((ref, folderPath) {
  return ref.watch(perFolderDbRegistryProvider).novelData(folderPath);
});
