import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/google_authorization.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/progress_sync_auth.dart';
import 'package:novel_viewer/features/progress_sync/domain/oauth_client.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';

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
  Uri? opened;

  @override
  Future<AuthorizationCode?> obtainCode({
    required Uri Function(String redirectUri) authorizationUrl,
    required String state,
  }) async {
    opened = authorizationUrl('http://127.0.0.1:5555');
    return result;
  }
}

String _idToken(String email) {
  String part(Map<String, Object> json) =>
      base64UrlEncode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'email': email})}.sig';
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

const _client = OAuthClient(
  signIn: ProgressSyncSignIn.desktop,
  clientId: 'cid',
  clientSecret: 'secret',
);

void main() {
  late _MemoryCredentials credentials;
  late _Receiver receiver;
  late List<http.Request> requests;
  late DateTime now;
  late int cleared;

  setUp(() {
    credentials = _MemoryCredentials();
    receiver = _Receiver();
    requests = [];
    now = DateTime.utc(2026, 10, 18, 12);
    cleared = 0;
  });

  ProgressSyncAuth authWith(
    Future<http.Response> Function(http.Request request) handler, {
    OAuthClient client = _client,
  }) {
    return ProgressSyncAuth(
      client: client,
      receiver: receiver,
      credentials: credentials,
      httpClient: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
      clearSyncState: () async => cleared++,
      now: () => now,
    );
  }

  group('sign-in', () {
    test('exchanges the code with PKCE and remembers the account', () async {
      final auth = authWith(
        (_) async => _json({
          'access_token': 'at-1',
          'expires_in': 3600,
          'refresh_token': 'rt-1',
          'id_token': _idToken('reader@example.com'),
        }),
      );

      expect(await auth.signIn(), isTrue);

      final exchange = requests.single;
      expect(exchange.url.toString(), 'https://oauth2.googleapis.com/token');
      final form = Uri.splitQueryString(exchange.body);
      expect(form['grant_type'], 'authorization_code');
      expect(form['code'], 'c0de');
      expect(form['redirect_uri'], 'http://127.0.0.1:5555');
      expect(form['client_id'], 'cid');
      expect(form['client_secret'], 'secret');
      final challenge = receiver.opened!.queryParameters['code_challenge'];
      final verifier = form['code_verifier']!;
      expect(
        challenge,
        pkceChallengeOf(verifier),
        reason: 'the verifier must belong to the challenge that was sent',
      );
      expect(
        auth.state.value,
        const SyncAccountState.signedIn('reader@example.com'),
      );
      expect(credentials.stored!.refreshToken, 'rt-1');
      expect(credentials.stored!.email, 'reader@example.com');
      expect(await auth.accessToken(), 'at-1');
      expect(requests, hasLength(1));
    });

    test('an iOS client sends no secret', () async {
      final auth = authWith(
        (_) async => _json({
          'access_token': 'at-1',
          'expires_in': 3600,
          'refresh_token': 'rt-1',
          'id_token': _idToken('reader@example.com'),
        }),
        client: const OAuthClient(
          signIn: ProgressSyncSignIn.ios,
          clientId: 'ios-cid',
        ),
      );

      await auth.signIn();

      final form = Uri.splitQueryString(requests.single.body);
      expect(form.containsKey('client_secret'), isFalse);
      expect(form['client_id'], 'ios-cid');
    });

    test('signing in as another account forgets the old sync state', () async {
      credentials.stored = const StoredCredentials(
        refreshToken: 'rt-old',
        email: 'old@example.com',
      );
      final auth = authWith(
        (_) async => _json({
          'access_token': 'at-1',
          'expires_in': 3600,
          'refresh_token': 'rt-new',
          'id_token': _idToken('new@example.com'),
        }),
      );
      await auth.load();

      expect(await auth.signIn(), isTrue);

      expect(cleared, 1);
      expect(
        auth.state.value,
        const SyncAccountState.signedIn('new@example.com'),
      );
    });

    test('signing in again as the same account keeps the sync state', () async {
      credentials.stored = const StoredCredentials(
        refreshToken: 'rt-old',
        email: 'reader@example.com',
      );
      final auth = authWith(
        (_) async => _json({
          'access_token': 'at-1',
          'expires_in': 3600,
          'refresh_token': 'rt-new',
          'id_token': _idToken('reader@example.com'),
        }),
      );
      await auth.load();

      await auth.signIn();

      expect(cleared, 0);
      expect(credentials.stored!.refreshToken, 'rt-new');
    });

    test('stays signed out when the reader cancels', () async {
      receiver.result = null;
      final auth = authWith((_) async => _json({}));

      expect(await auth.signIn(), isFalse);
      expect(auth.state.value, const SyncAccountState.signedOut());
      expect(requests, isEmpty);
      expect(credentials.stored, isNull);
    });

    test('stays signed out when the exchange fails', () async {
      final auth = authWith((_) async => _json({'error': 'bad'}, 400));

      expect(await auth.signIn(), isFalse);
      expect(auth.state.value, const SyncAccountState.signedOut());
    });
  });

  group('access tokens', () {
    ProgressSyncAuth signedInAuth(
      Future<http.Response> Function(http.Request request) handler,
    ) {
      credentials.stored = const StoredCredentials(
        refreshToken: 'rt-1',
        email: 'reader@example.com',
      );
      return authWith(handler);
    }

    test('restores the account from storage', () async {
      final auth = signedInAuth((_) async => _json({}));
      await auth.load();

      expect(
        auth.state.value,
        const SyncAccountState.signedIn('reader@example.com'),
      );
    });

    test('refreshes when no access token is held', () async {
      final auth = signedInAuth(
        (_) async => _json({'access_token': 'at-2', 'expires_in': 3600}),
      );
      await auth.load();

      expect(await auth.accessToken(), 'at-2');
      final form = Uri.splitQueryString(requests.single.body);
      expect(form['grant_type'], 'refresh_token');
      expect(form['refresh_token'], 'rt-1');
    });

    test('reuses a token until 60 seconds before it expires', () async {
      var issued = 0;
      final auth = signedInAuth((_) async {
        issued++;
        return _json({'access_token': 'at-$issued', 'expires_in': 3600});
      });
      await auth.load();

      expect(await auth.accessToken(), 'at-1');
      now = now.add(const Duration(seconds: 3600 - 61));
      expect(await auth.accessToken(), 'at-1');
      now = now.add(const Duration(seconds: 2));
      expect(await auth.accessToken(), 'at-2');
    });

    test('a forced refresh trades the token in', () async {
      var issued = 0;
      final auth = signedInAuth((_) async {
        issued++;
        return _json({'access_token': 'at-$issued', 'expires_in': 3600});
      });
      await auth.load();

      await auth.accessToken();
      expect(await auth.accessToken(forceRefresh: true), 'at-2');
    });

    test('a revoked grant asks the reader to sign in again', () async {
      final auth = signedInAuth(
        (_) async => _json({'error': 'invalid_grant'}, 400),
      );
      await auth.load();

      await expectLater(auth.accessToken(), throwsA(isA<SyncReauthRequired>()));
      expect(
        auth.state.value,
        const SyncAccountState.needsReauth('reader@example.com'),
      );
    });

    test('refuses while signed out', () async {
      final auth = authWith((_) async => _json({}));
      await auth.load();

      await expectLater(auth.accessToken(), throwsA(isA<SyncNotSignedIn>()));
      expect(requests, isEmpty);
    });
  });

  test('reads the email from an id token', () {
    expect(emailFromIdToken(_idToken('a@b.c')), 'a@b.c');
    expect(emailFromIdToken('not-a-jwt'), isNull);
  });

  group('sign-out', () {
    test('revokes, forgets the tokens and the sync state', () async {
      credentials.stored = const StoredCredentials(
        refreshToken: 'rt-1',
        email: 'reader@example.com',
      );
      final auth = authWith((_) async => _json({}));
      await auth.load();

      await auth.signOut();

      final revoke = requests.single;
      expect(revoke.url.toString(), 'https://oauth2.googleapis.com/revoke');
      expect(Uri.splitQueryString(revoke.body)['token'], 'rt-1');
      expect(credentials.stored, isNull);
      expect(cleared, 1);
      expect(auth.state.value, const SyncAccountState.signedOut());
      await expectLater(auth.accessToken(), throwsA(isA<SyncNotSignedIn>()));
    });

    test('is signed out before the sync state is cleared', () async {
      credentials.stored = const StoredCredentials(
        refreshToken: 'rt-1',
        email: 'reader@example.com',
      );
      late ProgressSyncAuth auth;
      SyncAccountState? stateWhenCleared;
      auth = ProgressSyncAuth(
        client: _client,
        receiver: receiver,
        credentials: credentials,
        httpClient: MockClient((_) async => _json({})),
        clearSyncState: () async => stateWhenCleared = auth.state.value,
        now: () => now,
      );
      await auth.load();

      await auth.signOut();

      expect(stateWhenCleared, const SyncAccountState.signedOut());
    });

    test('a failed revoke only logs a warning', () async {
      final records = <LogRecord>[];
      final sub = Logger('progress_sync').onRecord.listen(records.add);
      addTearDown(sub.cancel);
      credentials.stored = const StoredCredentials(
        refreshToken: 'rt-1',
        email: 'reader@example.com',
      );
      final auth = authWith((_) async => http.Response('down', 503));
      await auth.load();

      await auth.signOut();

      expect(credentials.stored, isNull);
      expect(cleared, 1);
      expect(records.any((r) => r.level == Level.WARNING), isTrue);
    });
  });
}
