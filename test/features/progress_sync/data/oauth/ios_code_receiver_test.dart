import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/google_authorization.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/ios_code_receiver.dart';

const _clientId = '1234-abcd.apps.googleusercontent.com';

Uri _authUrl(String redirectUri) => buildAuthorizationUrl(
  clientId: _clientId,
  redirectUri: redirectUri,
  codeChallenge: 'challenge',
  state: 's1',
);

void main() {
  test('the redirect URI is the reversed client id', () {
    expect(
      iosRedirectUriFor(_clientId),
      'com.googleusercontent.apps.1234-abcd:/oauthredirect',
    );
  });

  test('returns the code the session hands back', () async {
    late String openedUrl;
    late String scheme;
    final receiver = IosCodeReceiver(
      clientId: _clientId,
      authenticate: ({required url, required callbackUrlScheme}) async {
        openedUrl = url;
        scheme = callbackUrlScheme;
        return 'com.googleusercontent.apps.1234-abcd:/oauthredirect'
            '?code=c0de&state=s1';
      },
    );

    final result = await receiver.obtainCode(
      authorizationUrl: _authUrl,
      state: 's1',
    );

    expect(result!.code, 'c0de');
    expect(
      result.redirectUri,
      'com.googleusercontent.apps.1234-abcd:/oauthredirect',
    );
    expect(scheme, 'com.googleusercontent.apps.1234-abcd');
    expect(
      Uri.parse(openedUrl).queryParameters['redirect_uri'],
      result.redirectUri,
    );
  });

  test('refuses a callback whose state does not match', () async {
    final receiver = IosCodeReceiver(
      clientId: _clientId,
      authenticate: ({required url, required callbackUrlScheme}) async =>
          'com.googleusercontent.apps.1234-abcd:/oauthredirect'
          '?code=c0de&state=other',
    );

    expect(
      await receiver.obtainCode(authorizationUrl: _authUrl, state: 's1'),
      isNull,
    );
  });

  test('returns nothing when the reader denies access', () async {
    final receiver = IosCodeReceiver(
      clientId: _clientId,
      authenticate: ({required url, required callbackUrlScheme}) async =>
          'com.googleusercontent.apps.1234-abcd:/oauthredirect'
          '?error=access_denied&state=s1',
    );

    expect(
      await receiver.obtainCode(authorizationUrl: _authUrl, state: 's1'),
      isNull,
    );
  });

  test('returns nothing when the reader cancels the session', () async {
    final receiver = IosCodeReceiver(
      clientId: _clientId,
      authenticate: ({required url, required callbackUrlScheme}) async =>
          throw PlatformException(code: 'CANCELED'),
    );

    expect(
      await receiver.obtainCode(authorizationUrl: _authUrl, state: 's1'),
      isNull,
    );
  });
}
