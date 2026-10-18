import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';

import '../data/drive_progress_sync_store.dart';
import '../data/oauth/google_authorization.dart';
import '../data/oauth/ios_code_receiver.dart';
import '../data/oauth/loopback_code_receiver.dart';
import '../data/oauth/progress_sync_auth.dart';
import '../data/progress_sync_repository.dart';
import 'progress_sync_config_providers.dart';

final progressSyncRepositoryProvider = Provider<ProgressSyncRepository>(
  (ref) => ProgressSyncRepository(ref.watch(novelDatabaseProvider)),
);

const _driveFileIdKey = 'progress_sync_drive_file_id';

class PrefsDriveFileIdStore implements DriveFileIdStore {
  final SharedPreferences _prefs;
  PrefsDriveFileIdStore(this._prefs);

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

final syncHttpClientProvider = Provider<http.Client>((ref) {
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
    httpClient: ref.watch(syncHttpClientProvider),
    clearSyncState: () async {
      await ref.read(progressSyncRepositoryProvider).clearAll();
      await PrefsDriveFileIdStore(prefs).write(null);
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
