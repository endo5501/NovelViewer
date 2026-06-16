import 'package:flutter_riverpod/misc.dart'
    show ProviderListenable, ProviderOrFamily;

import '../../features/tts/providers/tts_audio_database_provider.dart';
import 'folder_db_key.dart';
import 'novel_data_database_provider.dart';
import 'per_folder_db_registry_provider.dart';

/// Releases the four per-folder database handles bound to [folderPath]
/// (`episode_cache.db`, `tts_audio.db`, `tts_dictionary.db`, `novel_data.db`)
/// before a file-system operation on that folder.
///
/// Closes them via the owning [PerFolderDbRegistry] (`closeAll`, awaited — so
/// the Windows file lock is gone before `Directory.rename`/`delete`), then
/// invalidates the three thin-view providers.
///
/// The invalidation is essential, not cosmetic: the per-folder providers are
/// non-autoDispose `Provider.family` and cache the wrapper they resolved. Once
/// the registry evicts a handle, an un-invalidated provider keeps serving the
/// evicted wrapper, whose gate would re-open an *untracked* connection on the
/// next `.database` access — re-locking the very file the close just released.
///
/// [read] and [invalidate] are passed as tear-offs from a provider `Ref` or a
/// `WidgetRef` so the move/rename/folder-delete (widget) and novel-delete
/// (provider) flows share one implementation.
Future<void> releaseFolderDbHandles(
  String folderPath, {
  required T Function<T>(ProviderListenable<T>) read,
  required void Function(ProviderOrFamily) invalidate,
}) async {
  await read(perFolderDbRegistryProvider).closeAll(folderPath);
  final key = folderDbKey(folderPath);
  invalidate(episodeCacheDatabaseProvider(key));
  invalidate(ttsAudioDatabaseProvider(key));
  invalidate(ttsDictionaryDatabaseProvider(key));
  invalidate(novelDataDatabaseProvider(key));
}
