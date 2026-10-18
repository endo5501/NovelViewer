import 'package:novel_viewer/shared/platform/platform_capabilities.dart';

/// The Google OAuth client values the build was given (design D9). They are
/// injected with `--dart-define` and never kept in the repository; a value
/// that was not injected is the empty string.
class OAuthClientConfig {
  final String desktopClientId;
  final String desktopClientSecret;
  final String iosClientId;

  const OAuthClientConfig({
    required this.desktopClientId,
    required this.desktopClientSecret,
    required this.iosClientId,
  });

  const OAuthClientConfig.fromEnvironment()
    : desktopClientId = const String.fromEnvironment(
        'GOOGLE_OAUTH_DESKTOP_CLIENT_ID',
      ),
      desktopClientSecret = const String.fromEnvironment(
        'GOOGLE_OAUTH_DESKTOP_CLIENT_SECRET',
      ),
      iosClientId = const String.fromEnvironment('GOOGLE_OAUTH_IOS_CLIENT_ID');

  bool get isEmpty =>
      desktopClientId.isEmpty &&
      desktopClientSecret.isEmpty &&
      iosClientId.isEmpty;
}

/// The OAuth client this platform signs in with.
class OAuthClient {
  final ProgressSyncSignIn signIn;
  final String clientId;

  /// Google's desktop clients require the secret at token exchange; it is not
  /// confidential in an installed app. iOS clients have none.
  final String? clientSecret;

  const OAuthClient({
    required this.signIn,
    required this.clientId,
    this.clientSecret,
  });
}

/// The client for [signIn], or null when the build lacks a value it needs:
/// the desktop flow needs the client id and secret, iOS only the client id.
OAuthClient? resolveOAuthClient(
  ProgressSyncSignIn signIn,
  OAuthClientConfig config,
) {
  switch (signIn) {
    case ProgressSyncSignIn.desktop:
      if (config.desktopClientId.isEmpty ||
          config.desktopClientSecret.isEmpty) {
        return null;
      }
      return OAuthClient(
        signIn: signIn,
        clientId: config.desktopClientId,
        clientSecret: config.desktopClientSecret,
      );
    case ProgressSyncSignIn.ios:
      if (config.iosClientId.isEmpty) return null;
      return OAuthClient(signIn: signIn, clientId: config.iosClientId);
  }
}
