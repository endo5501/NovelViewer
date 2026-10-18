import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/google_authorization.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/progress_sync_auth.dart';
import 'package:novel_viewer/features/progress_sync/data/progress_sync_runner.dart';
import 'package:novel_viewer/features/progress_sync/domain/oauth_client.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_providers.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_settings_providers.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';

class _RecordingRunner implements ProgressSyncRunner {
  final List<String> calls = [];
  Completer<void>? idleGate;

  @override
  Future<void> push() async => calls.add('push');

  @override
  Future<void> pull() async => calls.add('pull');

  @override
  Future<void> syncNow() async => calls.add('syncNow');

  @override
  Future<void> get idle => idleGate?.future ?? Future.value();
}

class _MemoryCredentials implements SyncCredentialStore {
  StoredCredentials? stored;

  @override
  Future<StoredCredentials?> read() async => stored;

  @override
  Future<void> write(StoredCredentials credentials) async =>
      stored = credentials;

  @override
  Future<void> delete() async => stored = null;
}

class _Receiver implements AuthorizationCodeReceiver {
  AuthorizationCode? result = const AuthorizationCode(
    code: 'c0de',
    redirectUri: 'http://127.0.0.1:5555',
  );

  @override
  Future<AuthorizationCode?> obtainCode({
    required Uri Function(String redirectUri) authorizationUrl,
    required String state,
  }) async => result;
}

String _idToken(String email) {
  String part(Map<String, Object> json) =>
      base64UrlEncode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'email': email})}.sig';
}

void main() {
  late _RecordingRunner runner;
  late _MemoryCredentials credentials;
  late _Receiver receiver;
  late bool cleared;

  setUp(() {
    runner = _RecordingRunner();
    credentials = _MemoryCredentials();
    receiver = _Receiver();
    cleared = false;
  });

  (ProviderContainer, ProgressSyncAuth) build() {
    final auth = ProgressSyncAuth(
      client: const OAuthClient(
        signIn: ProgressSyncSignIn.desktop,
        clientId: 'cid',
        clientSecret: 'secret',
      ),
      receiver: receiver,
      credentials: credentials,
      httpClient: MockClient((request) async {
        if (request.url.path == '/revoke') return http.Response('', 200);
        return http.Response(
          jsonEncode({
            'access_token': 'at',
            'expires_in': 3600,
            'refresh_token': 'rt',
            'id_token': _idToken('reader@example.com'),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      clearSyncState: () async => cleared = true,
    );
    final container = ProviderContainer(
      overrides: [
        progressSyncAuthProvider.overrideWithValue(auth),
        progressSyncRunnerProvider.overrideWithValue(runner),
      ],
    );
    addTearDown(container.dispose);
    return (container, auth);
  }

  test('a successful sign-in syncs straight away', () async {
    final (container, auth) = build();

    await container.read(syncAccountActionsProvider).signIn();

    expect(auth.state.value.status, SyncAccountStatus.signedIn);
    expect(runner.calls, ['syncNow']);
  });

  test('a cancelled sign-in does not sync', () async {
    receiver.result = null;
    final (container, _) = build();

    await container.read(syncAccountActionsProvider).signIn();

    expect(runner.calls, isEmpty);
  });

  test('sign-out waits for the running sync before clearing', () async {
    credentials.stored = const StoredCredentials(
      refreshToken: 'rt',
      email: 'reader@example.com',
    );
    final (container, auth) = build();
    await auth.load();
    runner.idleGate = Completer<void>();

    final signOut = container.read(syncAccountActionsProvider).signOut();
    await Future<void>.delayed(Duration.zero);

    expect(auth.state.value.status, SyncAccountStatus.signedOut);
    expect(cleared, isFalse, reason: 'a sync is still running');

    runner.idleGate!.complete();
    await signOut;
    expect(cleared, isTrue);
    expect(credentials.stored, isNull);
  });
}
