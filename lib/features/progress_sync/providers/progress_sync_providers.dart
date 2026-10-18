import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_position_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_download/data/sites/generic_web_site.dart';
import 'package:novel_viewer/shared/episode/episode_resolver.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';
import 'package:novel_viewer/shared/utils/novel_id_resolver.dart';

import '../data/device_identity.dart';
import '../data/drive_progress_sync_store.dart';
import '../data/oauth/google_authorization.dart';
import '../data/oauth/ios_code_receiver.dart';
import '../data/oauth/loopback_code_receiver.dart';
import '../data/oauth/progress_sync_auth.dart';
import '../data/progress_sync_repository.dart';
import '../data/progress_sync_service.dart';
import 'progress_sync_config_providers.dart';
import 'progress_sync_triggers.dart';

final progressSyncRepositoryProvider = Provider<ProgressSyncRepository>(
  (ref) => ProgressSyncRepository(ref.watch(novelDatabaseProvider)),
);

const _driveFileIdKey = 'progress_sync_drive_file_id';

class _PrefsDriveFileIdStore implements DriveFileIdStore {
  final SharedPreferences _prefs;
  _PrefsDriveFileIdStore(this._prefs);

  @override
  Future<String?> read() async => _prefs.getString(_driveFileIdKey);

  @override
  Future<void> write(String? id) async {
    if (id == null) {
      await _prefs.remove(_driveFileIdKey);
    } else {
      await _prefs.setString(_driveFileIdKey, id);
    }
  }
}

class _SecureCredentialStore implements SyncCredentialStore {
  static const _refreshTokenKey = 'progress_sync_refresh_token';
  static const _emailKey = 'progress_sync_email';

  final FlutterSecureStorage _storage;
  const _SecureCredentialStore(this._storage);

  @override
  Future<StoredCredentials?> read() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final email = await _storage.read(key: _emailKey);
    if (refreshToken == null || email == null) return null;
    return StoredCredentials(refreshToken: refreshToken, email: email);
  }

  @override
  Future<void> write(StoredCredentials credentials) async {
    await _storage.write(
      key: _refreshTokenKey,
      value: credentials.refreshToken,
    );
    await _storage.write(key: _emailKey, value: credentials.email);
  }

  @override
  Future<void> delete() async {
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _emailKey);
  }
}

final _syncHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// The signed-in Google account, or null in a build without sync.
final progressSyncAuthProvider = Provider<ProgressSyncAuth?>((ref) {
  final client = ref.watch(oauthClientProvider);
  if (client == null) return null;
  final prefs = ref.watch(sharedPreferencesProvider);
  final AuthorizationCodeReceiver receiver = switch (client.signIn) {
    ProgressSyncSignIn.desktop => LoopbackCodeReceiver(
      openBrowser: (url) =>
          launchUrl(url, mode: LaunchMode.externalApplication),
    ),
    ProgressSyncSignIn.ios => IosCodeReceiver(clientId: client.clientId),
  };
  final auth = ProgressSyncAuth(
    client: client,
    receiver: receiver,
    credentials: const _SecureCredentialStore(FlutterSecureStorage()),
    httpClient: ref.watch(_syncHttpClientProvider),
    clearSyncState: () async {
      await ref.read(progressSyncRepositoryProvider).clearAll();
      await _PrefsDriveFileIdStore(prefs).write(null);
    },
  );
  ref.onDispose(auth.state.dispose);
  return auth;
});

/// The account's state for the settings screen; signed out without sync.
final syncAccountStateProvider = Provider<SyncAccountState>((ref) {
  final auth = ref.watch(progressSyncAuthProvider);
  if (auth == null) return const SyncAccountState.signedOut();
  void onChange() => ref.invalidateSelf();
  auth.state.addListener(onChange);
  ref.onDispose(() => auth.state.removeListener(onChange));
  return auth.state.value;
});

final progressSyncServiceProvider = Provider<ProgressSyncService>((ref) {
  final auth = ref.watch(progressSyncAuthProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final identity = DeviceIdentity(prefs);
  final service = ProgressSyncService(
    isAvailable: () => ref.read(progressSyncAvailableProvider),
    isSignedIn: () => auth?.state.value.status == SyncAccountStatus.signedIn,
    store: DriveProgressSyncStore(
      client: ref.watch(_syncHttpClientProvider),
      tokens: auth ?? const _NoTokens(),
      fileIds: _PrefsDriveFileIdStore(prefs),
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
