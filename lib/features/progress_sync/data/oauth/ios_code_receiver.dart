import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:logging/logging.dart';

import 'google_authorization.dart';

final _log = Logger('progress_sync');

/// Shows [url] in a system authentication session and returns the callback
/// URL once the session is redirected to [callbackUrlScheme].
typedef AuthenticationSession =
    Future<String> Function({
      required String url,
      required String callbackUrlScheme,
    });

/// The redirect URI Google assigns an iOS client: its id with the domain
/// parts reversed, as a custom scheme.
String iosRedirectUriFor(String clientId) =>
    '${_reversedClientId(clientId)}:/oauthredirect';

String _reversedClientId(String clientId) =>
    clientId.split('.').reversed.join('.');

Future<String> _flutterWebAuth2({
  required String url,
  required String callbackUrlScheme,
}) {
  return FlutterWebAuth2.authenticate(
    url: url,
    callbackUrlScheme: callbackUrlScheme,
  );
}

/// iOS sign-in through ASWebAuthenticationSession (design D8). The session
/// catches the callback itself, so the scheme needs no Info.plist entry and
/// never reaches the app's `novelviewer://` link handling.
class IosCodeReceiver implements AuthorizationCodeReceiver {
  final String _clientId;
  final AuthenticationSession _authenticate;

  IosCodeReceiver({
    required String clientId,
    AuthenticationSession authenticate = _flutterWebAuth2,
  }) : _clientId = clientId,
       _authenticate = authenticate;

  @override
  Future<AuthorizationCode?> obtainCode({
    required Uri Function(String redirectUri) authorizationUrl,
    required String state,
  }) async {
    final redirectUri = iosRedirectUriFor(_clientId);
    final String callback;
    try {
      callback = await _authenticate(
        url: authorizationUrl(redirectUri).toString(),
        callbackUrlScheme: _reversedClientId(_clientId),
      );
    } catch (e, st) {
      _log.info('Google sign-in session ended without a result', e, st);
      return null;
    }
    final query = Uri.parse(callback).queryParameters;
    final code = query['code'];
    if (code == null || query['state'] != state) {
      _log.warning(
        'Google sign-in did not complete: '
        '${query['error'] ?? 'state mismatch'}',
      );
      return null;
    }
    return AuthorizationCode(code: code, redirectUri: redirectUri);
  }
}
