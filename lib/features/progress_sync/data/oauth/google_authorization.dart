import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// The scopes progress sync asks for: Drive's app-only folder, and the
/// account's email address to show in settings. Nothing else in the Drive.
const googleSyncScopes = [
  'openid',
  'email',
  'https://www.googleapis.com/auth/drive.appdata',
];

final googleAuthorizationEndpoint = Uri.parse(
  'https://accounts.google.com/o/oauth2/v2/auth',
);

/// A PKCE verifier and its S256 challenge (RFC 7636).
class PkcePair {
  final String verifier;
  final String challenge;

  const PkcePair._(this.verifier, this.challenge);

  factory PkcePair.generate([Random? random]) {
    final verifier = randomUrlSafeString(64, random);
    return PkcePair._(verifier, pkceChallengeOf(verifier));
  }
}

/// The S256 challenge for [verifier]: unpadded base64url of its SHA-256.
String pkceChallengeOf(String verifier) {
  return base64UrlEncode(
    sha256.convert(ascii.encode(verifier)).bytes,
  ).replaceAll('=', '');
}

/// A random string of [length] characters from the PKCE unreserved set, also
/// used for the OAuth `state`.
String randomUrlSafeString(int length, [Random? random]) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  final source = random ?? Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < length; i++)
      chars.codeUnitAt(source.nextInt(chars.length)),
  ]);
}

Uri buildAuthorizationUrl({
  required String clientId,
  required String redirectUri,
  required String codeChallenge,
  required String state,
}) {
  return googleAuthorizationEndpoint.replace(
    queryParameters: {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': googleSyncScopes.join(' '),
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'state': state,
      // A refresh token is what lets sync keep working without signing in
      // again; Google issues one only for offline access, and only on consent.
      'access_type': 'offline',
      'prompt': 'consent',
    },
  );
}

/// An authorization code and the redirect URI it was issued for, which the
/// token exchange must repeat.
class AuthorizationCode {
  final String code;
  final String redirectUri;

  const AuthorizationCode({required this.code, required this.redirectUri});
}

/// Obtains an authorization code from Google by showing the consent screen.
abstract class AuthorizationCodeReceiver {
  /// Opens the URL [authorizationUrl] builds for the receiver's redirect URI
  /// and waits for the redirect. Returns null when the reader cancels or
  /// denies, the redirect's `state` is not [state], or it takes too long.
  Future<AuthorizationCode?> obtainCode({
    required Uri Function(String redirectUri) authorizationUrl,
    required String state,
  });
}
