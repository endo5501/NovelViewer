import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tts_audio_database.dart';
import '../data/tts_dictionary_database.dart';
import '../../episode_cache/data/episode_cache_database.dart';

/// Per-folder cached `TtsAudioDatabase` keyed by absolute folder path.
///
/// `ref.onDispose` closes the underlying database when the family entry is
/// invalidated (e.g. on folder switch) or when the owning `ProviderContainer`
/// is disposed. Not `autoDispose` so multiple consumers in the current folder
/// share one instance even if their watch lifetimes differ.
final ttsAudioDatabaseProvider =
    Provider.family<TtsAudioDatabase, String>((ref, folderPath) {
  final db = TtsAudioDatabase(folderPath);
  ref.onDispose(() => db.close());
  return db;
});

final ttsDictionaryDatabaseProvider =
    Provider.family<TtsDictionaryDatabase, String>((ref, folderPath) {
  final db = TtsDictionaryDatabase(folderPath);
  ref.onDispose(() => db.close());
  return db;
});

final episodeCacheDatabaseProvider =
    Provider.family<EpisodeCacheDatabase, String>((ref, folderPath) {
  final db = EpisodeCacheDatabase(folderPath);
  ref.onDispose(() => db.close());
  return db;
});
