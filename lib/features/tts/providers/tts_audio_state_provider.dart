import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../data/tts_audio_repository.dart';
import '../domain/tts_episode.dart';
import '../domain/tts_episode_status.dart';
import 'tts_audio_database_provider.dart';
import 'tts_playback_providers.dart';

TtsAudioState _stateFromEpisode(TtsEpisode? episode) {
  if (episode == null) return TtsAudioState.none;
  switch (episode.status) {
    case TtsEpisodeStatus.generating:
      return TtsAudioState.generating;
    case TtsEpisodeStatus.partial:
    case TtsEpisodeStatus.completed:
      return TtsAudioState.ready;
  }
}

/// File path of the currently active streaming session, or null if no
/// generation is in flight. Set by `_startStreaming` so the UI can flip to
/// `generating` immediately, before the DB row exists. The DB-derived state
/// then takes over on completion via `ref.invalidate(ttsAudioStateProvider)`.
class ActiveStreamingFileNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? filePath) => state = filePath;
}

final activeStreamingFileProvider =
    NotifierProvider<ActiveStreamingFileNotifier, String?>(
  ActiveStreamingFileNotifier.new,
);

/// Per-file `TtsAudioState` derived from the cached `TtsAudioDatabase` for the
/// file's parent folder. Re-queries on `ref.invalidate(...)` so callers that
/// just wrote to the DB (e.g. streaming controller) can ask the UI to refresh.
final ttsAudioStateProvider =
    FutureProvider.family<TtsAudioState, String>((ref, filePath) async {
  if (ref.watch(activeStreamingFileProvider) == filePath) {
    return TtsAudioState.generating;
  }
  final folder = p.dirname(filePath);
  final fileName = p.basename(filePath);
  final db = ref.watch(ttsAudioDatabaseProvider(folder));
  final repo = TtsAudioRepository(db);
  final episode = await repo.findEpisodeByFileName(fileName);
  return _stateFromEpisode(episode);
});
