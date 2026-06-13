import 'package:flutter_riverpod/misc.dart'
    show ProviderListenable, ProviderOrFamily;
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';

/// Releases the three per-folder database handles bound to [folderPath]
/// (`episode_cache.db`, `tts_audio.db`, `tts_dictionary.db`) so a subsequent
/// file-system operation on that folder does not race an open SQLite file.
///
/// The handles are closed by `awaiting` `close()` directly **before** any
/// `invalidate`. `ref.invalidate` alone is fire-and-forget — its `onDispose`
/// `close()` is not awaited — so relying on it would race `Directory.rename` /
/// `delete` and fail under the Windows exclusive file lock. Callers MUST await
/// this helper before touching the file system.
///
/// All three handles are keyed via [folderDbKey] so the release reaches the
/// instance that other call sites (download flow, folder switch) opened,
/// regardless of path-separator spelling.
///
/// [read] and [invalidate] are passed as tear-offs from either a provider
/// `Ref` or a `WidgetRef` (`read: ref.read, invalidate: ref.invalidate`), which
/// lets the move/rename/folder-delete (widget) and novel-delete (provider)
/// flows share one implementation.
Future<void> releaseFolderDbHandles(
  String folderPath, {
  required T Function<T>(ProviderListenable<T>) read,
  required void Function(ProviderOrFamily) invalidate,
}) async {
  final key = folderDbKey(folderPath);
  await read(episodeCacheDatabaseProvider(key)).close();
  await read(ttsAudioDatabaseProvider(key)).close();
  await read(ttsDictionaryDatabaseProvider(key)).close();
  invalidate(episodeCacheDatabaseProvider(key));
  invalidate(ttsAudioDatabaseProvider(key));
  invalidate(ttsDictionaryDatabaseProvider(key));
}
