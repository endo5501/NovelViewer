import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_position_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_download/data/sites/generic_web_site.dart';
import 'package:novel_viewer/shared/episode/episode_resolver.dart';
import 'package:novel_viewer/shared/utils/novel_id_resolver.dart';

import '../data/device_identity.dart';
import '../data/drive_progress_sync_store.dart';
import '../data/oauth/progress_sync_auth.dart';
import '../data/progress_sync_service.dart';
import 'progress_sync_account_providers.dart';
import 'progress_sync_config_providers.dart';

export 'progress_sync_account_providers.dart';
import 'progress_sync_triggers.dart';

final progressSyncServiceProvider = Provider<ProgressSyncService>((ref) {
  final auth = ref.watch(progressSyncAuthProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final identity = DeviceIdentity(prefs);
  final service = ProgressSyncService(
    isAvailable: () => ref.read(progressSyncAvailableProvider),
    isSignedIn: () => auth?.state.value.status == SyncAccountStatus.signedIn,
    store: DriveProgressSyncStore(
      client: ref.watch(syncHttpClientProvider),
      tokens: auth ?? const _NoTokens(),
      fileIds: PrefsDriveFileIdStore(prefs),
    ),
    repository: ref.watch(progressSyncRepositoryProvider),
    deviceId: identity.deviceId,
    deviceName: buildDeviceName(
      platformLabel: platformLabelFor(Platform.operatingSystem),
      hostName: _hostName(),
    ),
    flushPendingPositions: () =>
        ref.read(readingPositionWriterProvider).flush(),
    loadLocalProgress: () =>
        ref.read(readingProgressRepositoryProvider).findAll(),
    syncableNovelIds: () async {
      final novels = await ref.read(allNovelsProvider.future);
      return {
        for (final novel in novels)
          if (novel.siteType != GenericWebSite.siteTypeId) novel.folderName,
      };
    },
    episodeOf: (novelId, fileName) async {
      final prefix = extractNumericPrefix(fileName);
      if (prefix != null) return prefix;
      final folder = await findNovelFolder(
        ref.read(libraryPathProvider),
        novelId,
      );
      if (folder == null) return null;
      return effectiveEpisodeOrNull(fileName, listSortedTextFileNames(folder));
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

final progressSyncRunnerProvider = Provider<ProgressSyncRunner>(
  (ref) => ref.watch(progressSyncServiceProvider),
);

class _NoTokens implements AccessTokenSource {
  const _NoTokens();

  @override
  Future<String> accessToken({bool forceRefresh = false}) =>
      Future.error(const SyncNotSignedIn());
}

String _hostName() {
  try {
    return Platform.localHostname;
  } catch (_) {
    return '';
  }
}

/// The folder of the registered novel [folderName] under [libraryRoot], at
/// any nesting depth, or null when there is none or more than one.
Future<String?> findNovelFolder(String? libraryRoot, String folderName) async {
  if (libraryRoot == null) return null;
  final matches = <String>[];
  final pending = <String>[libraryRoot];
  while (pending.isNotEmpty && matches.length < 2) {
    final directory = Directory(pending.removeLast());
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! Directory) continue;
        if (p.basename(entity.path) == folderName) {
          matches.add(entity.path);
        } else {
          pending.add(entity.path);
        }
      }
    } on FileSystemException {
      continue;
    }
  }
  return matches.length == 1 ? matches.single : null;
}

/// Restores the account a previous run signed in with, then pulls.
final progressSyncStartupProvider = FutureProvider<void>((ref) async {
  final auth = ref.read(progressSyncAuthProvider);
  if (auth == null) return;
  await auth.load();
  if (auth.state.value.status != SyncAccountStatus.signedIn) return;
  await ref.read(progressSyncRunnerProvider).pull();
});

/// Pulls and pushes on the app's lifecycle for as long as it is read.
final progressSyncLifecycleProvider = Provider<void>((ref) {
  final observer = ProgressSyncLifecycle(ref.read(progressSyncRunnerProvider));
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
});

/// Pushes when the reader leaves a novel: for another novel, the library
/// root, or a folder that is no novel. Moving inside one novel does not.
final progressSyncLeaveNovelListenerProvider = Provider<void>((ref) {
  ref.listen<String?>(currentDirectoryProvider, (previous, next) async {
    if (previous == null) return;
    final libraryPath = ref.read(libraryPathProvider);
    if (libraryPath == null) return;
    final novels = await ref.read(allNovelsProvider.future);
    final registered = {for (final n in novels) n.folderName};
    final left = resolveNovelId(libraryPath, previous, registered);
    if (left == null) return;
    final entered = next == null
        ? null
        : resolveNovelId(libraryPath, next, registered);
    if (left == entered) return;
    unawaited(ref.read(progressSyncRunnerProvider).push());
  });
});
