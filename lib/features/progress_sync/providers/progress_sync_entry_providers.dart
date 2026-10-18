import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';
import 'package:novel_viewer/shared/episode/episode_resolver.dart';

import '../data/oauth/progress_sync_auth.dart';
import '../data/progress_sync_repository.dart';
import '../domain/device_progress.dart';
import '../domain/sync_progress_record.dart';
import '../domain/sync_rules.dart';
import 'progress_sync_account_providers.dart';
import 'progress_sync_config_providers.dart';

export '../domain/sync_rules.dart'
    show
        SyncEntryDecision,
        NoSyncAction,
        AutoApplySync,
        PromptSync,
        MarkHandledSync;

/// Received records meeting a novel's own progress on folder entry (design
/// D6). Kept free of the reading-progress providers, which call into it.
class ProgressSyncEntry {
  final ProgressSyncRepository _sync;

  ProgressSyncEntry(this._sync);

  /// Decides against [local] as it was before the entry selected anything.
  /// [folderFiles] is the novel folder's `.txt` names.
  Future<SyncEntryDecision> decide({
    required String novelId,
    required ReadingProgress? local,
    required List<String> folderFiles,
  }) async {
    final remote = await _sync.findRemoteByNovel(novelId);
    if (remote.isEmpty) return const NoSyncAction();
    final sortedFiles = [...folderFiles]..sort();
    SyncProgressRecord? currentOwn;
    if (local != null) {
      final episode = effectiveEpisodeOrNull(local.fileName, sortedFiles);
      if (episode != null) {
        currentOwn = buildOwnRecord(
          local: local,
          episode: episode,
          lastPushed: (await _sync.findAllOwn())[novelId],
        );
      }
    }
    return decideOnEntry(
      local: local,
      currentOwn: currentOwn,
      remote: remote,
      handled: await _sync.findHandled(novelId),
      folderFiles: sortedFiles,
    );
  }

  /// Makes [remote] this device's progress for its novel, at the local file
  /// [fileName]. It is also recorded as pushed, under the origin device's
  /// `read_at`: this device did not read there, and must not come back to
  /// the origin looking as if it had.
  Future<ReadingProgress?> adopt({
    required ReadingProgressRepository progress,
    required RemoteProgress remote,
    required String fileName,
  }) async {
    final record = remote.record;
    await progress.upsert(novelId: record.novelId, fileName: fileName);
    final hash = record.bodyHash;
    if (hash != null) {
      await progress.savePosition(
        novelId: record.novelId,
        fileName: fileName,
        bodyOffset: record.bodyOffset,
        bodyHash: hash,
      );
    }
    await _sync.upsertOwn(
      SyncProgressRecord(
        novelId: record.novelId,
        episode: record.episode,
        fileName: fileName,
        bodyOffset: hash == null ? 0 : record.bodyOffset,
        bodyHash: hash,
        readAt: record.readAt,
      ),
    );
    return progress.findByNovelId(record.novelId);
  }

  Future<void> markHandled(String novelId, DateTime readAt) =>
      _sync.saveHandled(novelId, readAt);
}

/// The entry reconciliation, or null when sync is off or signed out, in which
/// case auto-open behaves exactly as it does without sync.
final progressSyncEntryProvider = Provider<ProgressSyncEntry?>((ref) {
  if (!ref.watch(progressSyncAvailableProvider)) return null;
  if (ref.watch(syncAccountStateProvider).status !=
      SyncAccountStatus.signedIn) {
    return null;
  }
  return ProgressSyncEntry(ref.watch(progressSyncRepositoryProvider));
});

/// A pending "move to the other device's position?" question.
class SyncPromptRequest {
  final String novelId;

  /// The novel folder the question is about; it is moot once the reader
  /// leaves it.
  final String directory;
  final RemoteProgress remote;

  /// The local file holding the remote record's episode.
  final String fileName;

  const SyncPromptRequest({
    required this.novelId,
    required this.directory,
    required this.remote,
    required this.fileName,
  });
}

class SyncPromptNotifier extends Notifier<SyncPromptRequest?> {
  @override
  SyncPromptRequest? build() => null;

  void show(SyncPromptRequest request) => state = request;

  void clear() => state = null;
}

final syncPromptProvider =
    NotifierProvider<SyncPromptNotifier, SyncPromptRequest?>(
      SyncPromptNotifier.new,
    );
