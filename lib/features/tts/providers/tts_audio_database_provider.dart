import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tts_audio_database.dart';
import '../data/tts_dictionary_database.dart';
import '../../episode_cache/data/episode_cache_database.dart';
import '../../../shared/database/per_folder_db_registry_provider.dart';

/// Per-folder `TtsAudioDatabase`, a thin view over [perFolderDbRegistryProvider].
///
/// The registry owns the handle's open/close lifecycle (keyed by the
/// normalized folder path) and releases it via `closeAll(folder)`. These
/// providers no longer close handles in `onDispose`: ownership lives in one
/// place so a new consumer cannot reintroduce the Windows file-lock bug.
final ttsAudioDatabaseProvider =
    Provider.family<TtsAudioDatabase, String>((ref, folderPath) {
  return ref.watch(perFolderDbRegistryProvider).ttsAudio(folderPath);
});

final ttsDictionaryDatabaseProvider =
    Provider.family<TtsDictionaryDatabase, String>((ref, folderPath) {
  return ref.watch(perFolderDbRegistryProvider).ttsDictionary(folderPath);
});

final episodeCacheDatabaseProvider =
    Provider.family<EpisodeCacheDatabase, String>((ref, folderPath) {
  return ref.watch(perFolderDbRegistryProvider).episodeCache(folderPath);
});
