import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../domain/oauth_client.dart';
import '../drive_progress_sync_store.dart';
import 'google_authorization.dart';

final _log = Logger('progress_sync');

final _tokenEndpoint = Uri.parse('https://oauth2.googleapis.com/token');
final _revokeEndpoint = Uri.parse('https://oauth2.googleapis.com/revoke');

/// An access token is renewed this long before Google says it expires, so a
/// request does not set out with a token that lapses on the way.
const _expiryMargin = Duration(seconds: 60);

enum SyncAccountStatus { signedOut, signedIn, needsReauth }

class SyncAccountState {
  final SyncAccountStatus status;

  /// The signed-in account, shown in settings. Null while signed out.
  final String? email;

  const SyncAccountState.signedOut()
    : status = SyncAccountStatus.signedOut,
      email = null;

  const SyncAccountState.signedIn(String this.email)
    : status = SyncAccountStatus.signedIn;

  /// Google refused the stored grant (expired or revoked): sync stops until
  /// the reader signs in again.
  const SyncAccountState.needsReauth(String this.email)
    : status = SyncAccountStatus.needsReauth;

  @override
  bool operator ==(Object other) =>
      other is SyncAccountState &&
      other.status == status &&
      other.email == email;

  @override
  int get hashCode => Object.hash(status, email);

  @override
  String toString() => 'SyncAccountState(${status.name}, $email)';
}

/// What survives a restart: the long-lived grant and the account it is for.
class StoredCredentials {
  final String refreshToken;
  final String email;

  const StoredCredentials({required this.refreshToken, required this.email});
}

/// Keeps [StoredCredentials] in the platform's secure storage.
abstract class SyncCredentialStore {
  Future<StoredCredentials?> read();
  Future<void> write(StoredCredentials credentials);
  Future<void> delete();
}

class SyncNotSignedIn implements Exception {
  const SyncNotSignedIn();

  @override
  String toString() => 'SyncNotSignedIn';
}

class SyncReauthRequired implements Exception {
  const SyncReauthRequired();

  @override
  String toString() => 'SyncReauthRequired';
}

/// The `email` claim of an OpenID Connect id token, or null when [idToken]
/// cannot be read. The token comes straight from Google's token endpoint over
/// TLS, so its signature is not checked here.
String? emailFromIdToken(String idToken) {
  final parts = idToken.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return (payload as Map<String, dynamic>)['email'] as String?;
  } on FormatException {
    return null;
  }
}

/// The Google account progress sync acts as: signing in and out, and the
/// access tokens Drive requests carry (design D8).
class ProgressSyncAuth implements AccessTokenSource {
  final OAuthClient _client;
  final AuthorizationCodeReceiver _receiver;
  final SyncCredentialStore _credentials;
  final http.Client _http;
  final Future<void> Function() _clearSyncState;
  final DateTime Function() _now;

  final ValueNotifier<SyncAccountState> state = ValueNotifier(
    const SyncAccountState.signedOut(),
  );

  StoredCredentials? _stored;
  String? _accessToken;
  DateTime? _expiresAt;

  ProgressSyncAuth({
    required OAuthClient client,
    required AuthorizationCodeReceiver receiver,
    required SyncCredentialStore credentials,
    required http.Client httpClient,
    required Future<void> Function() clearSyncState,
    DateTime Function()? now,
  }) : _client = client,
       _receiver = receiver,
       _credentials = credentials,
       _http = httpClient,
       _clearSyncState = clearSyncState,
       _now = now ?? DateTime.now;

  /// Restores the account a previous run signed in with.
  Future<void> load() async {
    _stored = await _credentials.read();
    state.value = switch (_stored) {
      final stored? => SyncAccountState.signedIn(stored.email),
      null => const SyncAccountState.signedOut(),
    };
  }

  /// Shows Google's consent screen and signs in. Returns false, staying
  /// signed out, when the reader cancels or the exchange fails.
  Future<bool> signIn() async {
    final pkce = PkcePair.generate();
    final expectedState = randomUrlSafeString(32);
    final code = await _receiver.obtainCode(
      authorizationUrl: (redirectUri) => buildAuthorizationUrl(
        clientId: _client.clientId,
        redirectUri: redirectUri,
        codeChallenge: pkce.challenge,
        state: expectedState,
      ),
      state: expectedState,
    );
    if (code == null) return false;
    try {
      final json = await _postToken({
        'grant_type': 'authorization_code',
        'code': code.code,
        'code_verifier': pkce.verifier,
        'redirect_uri': code.redirectUri,
      });
      final refreshToken = json['refresh_token'] as String?;
      final email = switch (json['id_token']) {
        final String idToken => emailFromIdToken(idToken),
        _ => null,
      };
      if (refreshToken == null || email == null) {
        _log.warning('Google sign-in returned no refresh token or email');
        return false;
      }
      _stored = StoredCredentials(refreshToken: refreshToken, email: email);
      await _credentials.write(_stored!);
      _holdAccessToken(json);
      state.value = SyncAccountState.signedIn(email);
      return true;
    } catch (e, st) {
      _log.warning('Google sign-in failed at the token exchange', e, st);
      return false;
    }
  }

  /// Signs out: asks Google to revoke the grant (best effort), then forgets
  /// the grant and everything sync learned under it. The device's own reading
  /// progress and its file on Drive stay.
  Future<void> signOut() async {
    final stored = _stored;
    if (stored != null) {
      try {
        final response = await _http.post(
          _revokeEndpoint,
          body: {'token': stored.refreshToken},
        );
        if (response.statusCode != 200) {
          _log.warning(
            'Google did not revoke the sync grant: ${response.statusCode}',
          );
        }
      } catch (e, st) {
        _log.warning('Could not reach Google to revoke the sync grant', e, st);
      }
    }
    _stored = null;
    _accessToken = null;
    _expiresAt = null;
    await _credentials.delete();
    await _clearSyncState();
    state.value = const SyncAccountState.signedOut();
  }

  @override
  Future<String> accessToken({bool forceRefresh = false}) async {
    final stored = _stored;
    if (stored == null || state.value.status != SyncAccountStatus.signedIn) {
      throw state.value.status == SyncAccountStatus.needsReauth
          ? const SyncReauthRequired()
          : const SyncNotSignedIn();
    }
    final token = _accessToken;
    final expiresAt = _expiresAt;
    if (!forceRefresh &&
        token != null &&
        expiresAt != null &&
        _now().isBefore(expiresAt.subtract(_expiryMargin))) {
      return token;
    }
    try {
      final json = await _postToken({
        'grant_type': 'refresh_token',
        'refresh_token': stored.refreshToken,
      });
      return _holdAccessToken(json);
    } on _TokenError catch (e) {
      if (e.error == 'invalid_grant') {
        _accessToken = null;
        state.value = SyncAccountState.needsReauth(stored.email);
        throw const SyncReauthRequired();
      }
      rethrow;
    }
  }

  String _holdAccessToken(Map<String, dynamic> json) {
    final token = json['access_token'] as String;
    _accessToken = token;
    _expiresAt = _now().add(Duration(seconds: json['expires_in'] as int));
    return token;
  }

  Future<Map<String, dynamic>> _postToken(Map<String, String> fields) async {
    final response = await _http.post(
      _tokenEndpoint,
      body: {
        ...fields,
        'client_id': _client.clientId,
        'client_secret': ?_client.clientSecret,
      },
    );
    final Object? json = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode != 200) {
      final error = json is Map<String, dynamic> ? json['error'] : null;
      throw _TokenError(response.statusCode, error as String?);
    }
    return json as Map<String, dynamic>;
  }
}

class _TokenError implements Exception {
  final int statusCode;
  final String? error;

  const _TokenError(this.statusCode, this.error);

  @override
  String toString() => 'Google token endpoint answered $statusCode: $error';
}
