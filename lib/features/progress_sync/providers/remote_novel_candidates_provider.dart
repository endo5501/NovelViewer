import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

import '../data/oauth/progress_sync_auth.dart';
import '../domain/device_progress.dart';
import '../domain/remote_novel_candidates.dart';
import 'progress_sync_config_providers.dart';
import 'progress_sync_providers.dart';

/// The novels other devices read that this device does not have, to offer in
/// the download dialog (remote-novel-download). Built from the records the
/// last pull stored, never by asking Drive; empty without sync or sign-in,
/// without reading them at all. Rebuilt after each pull, and when the
/// library changes so a downloaded novel drops out.
final remoteNovelCandidatesProvider = FutureProvider<List<RemoteProgress>>((
  ref,
) async {
  if (!ref.watch(progressSyncAvailableProvider)) return const [];
  if (ref.watch(syncAccountStateProvider).status !=
      SyncAccountStatus.signedIn) {
    return const [];
  }
  final subscription = ref
      .watch(progressSyncPulledProvider)
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(subscription.cancel);

  final novels = await ref.watch(allNovelsProvider.future);
  final remote = await ref.read(progressSyncRepositoryProvider).findAllRemote();
  final registry = NovelSiteRegistry();
  return buildRemoteNovelCandidates(
    remote: remote,
    registeredFolderNames: {for (final novel in novels) novel.folderName},
    urlMatches: (url, novelId) =>
        urlPointsToNovelFolder(url, novelId, registry: registry),
  );
});
