import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';
import 'package:novel_viewer/shared/episode/episode_resolver.dart';

import 'device_progress.dart';
import 'sync_progress_record.dart';

/// How far, in UTF-16 units, a position may drift within one episode and
/// still count as the same position. A restore shows the saved offset, but
/// the next capture records the first visible line (horizontal) or the page
/// start (vertical), which can sit up to a page earlier. Without this slack a
/// device that merely opened a novel would look as if it had read on.
const int samePositionTolerance = 1000;

bool isSamePosition(SyncProgressRecord a, SyncProgressRecord b) {
  return a.episode == b.episode &&
      (a.bodyOffset - b.bodyOffset).abs() < samePositionTolerance;
}

/// What this device publishes about a novel besides its position: the work
/// URL and title from its registration (design D3).
class SyncNovelInfo {
  final String? url;
  final String? title;

  const SyncNovelInfo({this.url, this.title});
}

/// This device's record for one novel. [lastPushed] is what the device last
/// published (or adopted from another device). While the position stays
/// within [samePositionTolerance] of it, [lastPushed] is published again as
/// it is, `read_at` and offset alike: opening a novel must not make the device
/// look like it read further (design D3), and keeping the offset as well
/// means small advances add up against one anchor instead of each being
/// measured from the last. [url] and [title] never move `read_at`, but a
/// change to either still makes the record differ from [lastPushed], so it is
/// published again (design D2).
SyncProgressRecord buildOwnRecord({
  required ReadingProgress local,
  required int episode,
  required SyncProgressRecord? lastPushed,
  String? url,
  String? title,
}) {
  final current = SyncProgressRecord(
    novelId: local.novelId,
    episode: episode,
    fileName: local.fileName,
    bodyOffset: local.bodyOffset,
    bodyHash: local.bodyHash,
    readAt: local.updatedAt.toUtc(),
    url: url,
    title: title,
  );
  if (lastPushed == null || !isSamePosition(current, lastPushed)) {
    return current;
  }
  return SyncProgressRecord(
    novelId: current.novelId,
    episode: current.episode,
    fileName: current.fileName,
    bodyOffset: lastPushed.bodyOffset,
    bodyHash: current.bodyHash,
    readAt: lastPushed.readAt,
    url: url,
    title: title,
  );
}

/// The records this device publishes: one per novel in [syncableNovels]
/// (registered novels other than generic-web collections) whose episode
/// [episodeOf] can name, carrying that novel's [SyncNovelInfo].
List<SyncProgressRecord> buildOwnRecords({
  required List<ReadingProgress> local,
  required Map<String, SyncNovelInfo> syncableNovels,
  required Map<String, SyncProgressRecord> lastPushed,
  required int? Function(String novelId, String fileName) episodeOf,
}) {
  return [
    for (final progress in local)
      if (syncableNovels[progress.novelId] case final info?)
        if (episodeOf(progress.novelId, progress.fileName) case final episode?)
          buildOwnRecord(
            local: progress,
            episode: episode,
            lastPushed: lastPushed[progress.novelId],
            url: info.url,
            title: info.title,
          ),
  ];
}

/// The file in [folderFiles] that [record] points at: the single file with
/// the record's effective episode number, else the file with the record's
/// name, else none (the episode is not on this device yet).
String? resolveEpisodeFile(
  SyncProgressRecord record,
  List<String> folderFiles,
) {
  final byEpisode = [
    for (final file in folderFiles)
      if (effectiveEpisodeOrNull(file, folderFiles) == record.episode) file,
  ];
  if (byEpisode.length == 1) return byEpisode.single;
  return folderFiles.contains(record.fileName) ? record.fileName : null;
}

/// What to do with received records on entering a novel folder (design D6).
sealed class SyncEntryDecision {
  const SyncEntryDecision();
}

class NoSyncAction extends SyncEntryDecision {
  const NoSyncAction();
}

/// This device has no progress for the novel: open [remote] at [fileName].
class AutoApplySync extends SyncEntryDecision {
  final RemoteProgress remote;
  final String fileName;
  const AutoApplySync(this.remote, this.fileName);
}

/// Open the local progress, then ask whether to move to [remote].
class PromptSync extends SyncEntryDecision {
  final RemoteProgress remote;
  final String fileName;
  const PromptSync(this.remote, this.fileName);
}

/// [readAt] is newer but at the reader's own position: nothing to ask.
class MarkHandledSync extends SyncEntryDecision {
  final DateTime readAt;
  const MarkHandledSync(this.readAt);
}

/// Decides against the state from before the entry's own selection, since
/// selecting a file touches `updated_at`. [currentOwn] is [buildOwnRecord]
/// for [local], or null when its episode is unknown; [handled] is the newest
/// `read_at` already answered for this novel.
SyncEntryDecision decideOnEntry({
  required ReadingProgress? local,
  required SyncProgressRecord? currentOwn,
  required List<RemoteProgress> remote,
  required DateTime? handled,
  required List<String> folderFiles,
}) {
  if (remote.isEmpty) return const NoSyncAction();
  final newest = remote.reduce(
    (a, b) => b.record.readAt.isAfter(a.record.readAt) ? b : a,
  );
  final readAt = newest.record.readAt;
  final fileName = resolveEpisodeFile(newest.record, folderFiles);

  if (local == null) {
    return fileName == null
        ? const NoSyncAction()
        : AutoApplySync(newest, fileName);
  }

  final ownReadAt = currentOwn?.readAt ?? local.updatedAt;
  if (!readAt.isAfter(ownReadAt)) return const NoSyncAction();
  if (handled != null && !readAt.isAfter(handled)) return const NoSyncAction();
  if (currentOwn != null && isSamePosition(newest.record, currentOwn)) {
    return MarkHandledSync(readAt);
  }
  if (fileName == null) return const NoSyncAction();
  return PromptSync(newest, fileName);
}
