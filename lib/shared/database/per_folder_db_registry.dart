import 'dart:async';

import '../../features/episode_cache/data/episode_cache_database.dart';
import '../../features/tts/data/tts_audio_database.dart';
import '../../features/tts/data/tts_dictionary_database.dart';
import 'folder_db_key.dart';

/// Owns the lifecycle of the three per-folder database handles
/// (`episode_cache.db`, `tts_audio.db`, `tts_dictionary.db`) for every novel
/// folder, keyed by the normalized [folderDbKey].
///
/// This is the single sanctioned owner of per-folder handles: Riverpod
/// providers are thin views that read from here, and folder mutation flows
/// (move / rename / empty-folder delete / novel delete) release handles only
/// via [closeAll]. Centralizing ownership means a new consumer cannot
/// reintroduce the "open SQLite file races a `Directory.rename`/`delete`"
/// lock bug by forgetting to choreograph `close()` itself.
class PerFolderDbRegistry {
  PerFolderDbRegistry({
    EpisodeCacheDatabase Function(String folder)? episodeFactory,
    TtsAudioDatabase Function(String folder)? audioFactory,
    TtsDictionaryDatabase Function(String folder)? dictionaryFactory,
  })  : _episodeFactory = episodeFactory ?? EpisodeCacheDatabase.new,
        _audioFactory = audioFactory ?? TtsAudioDatabase.new,
        _dictionaryFactory = dictionaryFactory ?? TtsDictionaryDatabase.new;

  final EpisodeCacheDatabase Function(String folder) _episodeFactory;
  final TtsAudioDatabase Function(String folder) _audioFactory;
  final TtsDictionaryDatabase Function(String folder) _dictionaryFactory;

  final _episode = <String, EpisodeCacheDatabase>{};
  final _audio = <String, TtsAudioDatabase>{};
  final _dictionary = <String, TtsDictionaryDatabase>{};

  EpisodeCacheDatabase episodeCache(String folder) {
    final key = folderDbKey(folder);
    return _episode.putIfAbsent(key, () => _episodeFactory(key));
  }

  TtsAudioDatabase ttsAudio(String folder) {
    final key = folderDbKey(folder);
    return _audio.putIfAbsent(key, () => _audioFactory(key));
  }

  TtsDictionaryDatabase ttsDictionary(String folder) {
    final key = folderDbKey(folder);
    return _dictionary.putIfAbsent(key, () => _dictionaryFactory(key));
  }

  /// Closes the three handles bound to [folder] (if open), awaiting each
  /// `close()` before evicting it from the cache. Callers MUST await this
  /// before any file-system operation on the folder so the SQLite files are
  /// unlocked first.
  Future<void> closeAll(String folder) async {
    final key = folderDbKey(folder);
    // Close first (awaited), then evict — matching the legacy release order
    // (await close → release). The handle stays in the map during its own
    // close so a concurrent access hits the closing gate rather than opening a
    // fresh handle that would re-lock the file.
    await _episode[key]?.close();
    await _audio[key]?.close();
    await _dictionary[key]?.close();
    _episode.remove(key);
    _audio.remove(key);
    _dictionary.remove(key);
  }

  /// Evicts [folder]'s handles synchronously and closes them in the
  /// background. For folder-switch cleanup, where no file-system operation
  /// races the close: a synchronous eviction (so a return visit opens fresh
  /// handles) is what matters, and the close need not be awaited. Mutation
  /// flows that DO race a file operation (move/rename/delete) MUST use the
  /// awaited [closeAll] instead.
  void releaseInBackground(String folder) {
    final key = folderDbKey(folder);
    final episode = _episode.remove(key);
    final audio = _audio.remove(key);
    final dictionary = _dictionary.remove(key);
    if (episode != null) unawaited(episode.close());
    if (audio != null) unawaited(audio.close());
    if (dictionary != null) unawaited(dictionary.close());
  }

  /// Best-effort release of every open handle, for container teardown.
  Future<void> disposeAll() async {
    final episodes = _episode.values.toList();
    final audios = _audio.values.toList();
    final dictionaries = _dictionary.values.toList();
    _episode.clear();
    _audio.clear();
    _dictionary.clear();
    for (final db in episodes) {
      await db.close();
    }
    for (final db in audios) {
      await db.close();
    }
    for (final db in dictionaries) {
      await db.close();
    }
  }
}
