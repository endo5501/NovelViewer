import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/google_authorization.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/loopback_code_receiver.dart';

/// Plays the browser: follows the authorization URL's redirect back to the
/// app with the query [reply] builds from the request's state.
Future<bool> Function(Uri) _browserReplying(
  Map<String, String> Function(String state) reply,
) {
  return (authorizationUrl) async {
    final redirect = Uri.parse(
      authorizationUrl.queryParameters['redirect_uri']!,
    );
    final state = authorizationUrl.queryParameters['state']!;
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        redirect.replace(queryParameters: reply(state)),
      );
      await (await request.close()).drain<void>();
    } finally {
      client.close();
    }
    return true;
  };
}

Uri Function(String) _authUrlWithState(String state) {
  return (redirectUri) => buildAuthorizationUrl(
    clientId: 'cid',
    redirectUri: redirectUri,
    codeChallenge: 'challenge',
    state: state,
  );
}

void main() {
  group('PkcePair', () {
    test('the challenge is the S256 of the verifier', () {
      final pair = PkcePair.generate(Random(1));
      final expected = base64UrlEncode(
        sha256.convert(ascii.encode(pair.verifier)).bytes,
      ).replaceAll('=', '');

      expect(pair.challenge, expected);
      expect(pair.verifier.length, inInclusiveRange(43, 128));
      expect(pair.verifier, matches(RegExp(r'^[A-Za-z0-9\-._~]+$')));
    });

    test('each pair is different', () {
      expect(PkcePair.generate().verifier, isNot(PkcePair.generate().verifier));
    });
  });

  test('the authorization URL asks only for the sync scopes', () {
    final url = buildAuthorizationUrl(
      clientId: 'cid',
      redirectUri: 'http://127.0.0.1:1234',
      codeChallenge: 'challenge',
      state: 'st',
    );

    expect(url.host, 'accounts.google.com');
    expect(url.queryParameters['client_id'], 'cid');
    expect(url.queryParameters['redirect_uri'], 'http://127.0.0.1:1234');
    expect(url.queryParameters['response_type'], 'code');
    expect(url.queryParameters['code_challenge'], 'challenge');
    expect(url.queryParameters['code_challenge_method'], 'S256');
    expect(url.queryParameters['state'], 'st');
    expect(url.queryParameters['access_type'], 'offline');
    expect(url.queryParameters['scope']!.split(' ').toSet(), {
      'openid',
      'email',
      'https://www.googleapis.com/auth/drive.appdata',
    });
  });

  group('LoopbackCodeReceiver', () {
    test('returns the code the browser hands back on loopback', () async {
      final receiver = LoopbackCodeReceiver(
        openBrowser: _browserReplying(
          (state) => {'code': 'c0de', 'state': state},
        ),
      );

      final result = await receiver.obtainCode(
        authorizationUrl: _authUrlWithState('s1'),
        state: 's1',
      );

      expect(result, isNotNull);
      expect(result!.code, 'c0de');
      expect(Uri.parse(result.redirectUri).host, '127.0.0.1');
    });

    test('refuses a redirect whose state does not match', () async {
      final receiver = LoopbackCodeReceiver(
        openBrowser: _browserReplying(
          (_) => {'code': 'c0de', 'state': 'other'},
        ),
      );

      expect(
        await receiver.obtainCode(
          authorizationUrl: _authUrlWithState('s1'),
          state: 's1',
        ),
        isNull,
      );
    });

    test('returns nothing when the reader denies access', () async {
      final receiver = LoopbackCodeReceiver(
        openBrowser: _browserReplying(
          (state) => {'error': 'access_denied', 'state': state},
        ),
      );

      expect(
        await receiver.obtainCode(
          authorizationUrl: _authUrlWithState('s1'),
          state: 's1',
        ),
        isNull,
      );
    });

    test('gives up when no redirect arrives in time', () async {
      final receiver = LoopbackCodeReceiver(
        openBrowser: (_) async => true,
        timeout: const Duration(milliseconds: 100),
      );

      expect(
        await receiver.obtainCode(
          authorizationUrl: _authUrlWithState('s1'),
          state: 's1',
        ),
        isNull,
      );
    });

    test('returns nothing when the browser cannot be opened', () async {
      final receiver = LoopbackCodeReceiver(openBrowser: (_) async => false);

      expect(
        await receiver.obtainCode(
          authorizationUrl: _authUrlWithState('s1'),
          state: 's1',
        ),
        isNull,
      );
    });

    test('stops listening once it is done', () async {
      late Uri redirect;
      final receiver = LoopbackCodeReceiver(
        openBrowser: (url) async {
          redirect = Uri.parse(url.queryParameters['redirect_uri']!);
          return true;
        },
        timeout: const Duration(milliseconds: 50),
      );
      await receiver.obtainCode(
        authorizationUrl: _authUrlWithState('s1'),
        state: 's1',
      );

      final client = HttpClient();
      addTearDown(client.close);
      await expectLater(
        client.getUrl(redirect).then((r) => r.close()),
        throwsA(isA<SocketException>()),
      );
    });
  });
}
