import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';

import 'google_authorization.dart';

final _log = Logger('progress_sync');

/// Desktop sign-in: the browser shows Google's consent screen and redirects
/// to a server this app runs on a loopback address (design D8). Only the
/// loopback interface is bound, so nothing outside the machine can reach it.
class LoopbackCodeReceiver implements AuthorizationCodeReceiver {
  final Future<bool> Function(Uri url) _openBrowser;
  final Duration _timeout;

  LoopbackCodeReceiver({
    required Future<bool> Function(Uri url) openBrowser,
    Duration timeout = const Duration(minutes: 5),
  }) : _openBrowser = openBrowser,
       _timeout = timeout;

  @override
  Future<AuthorizationCode?> obtainCode({
    required Uri Function(String redirectUri) authorizationUrl,
    required String state,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://${server.address.address}:${server.port}';
    try {
      // Listen before the browser opens, so a redirect that comes back at
      // once is not missed.
      final redirect = _awaitRedirect(server, state);
      if (!await _openBrowser(authorizationUrl(redirectUri))) {
        _log.warning('Could not open the browser for Google sign-in');
        return null;
      }
      final code = await redirect.timeout(
        _timeout,
        onTimeout: () {
          _log.info('Google sign-in timed out');
          return null;
        },
      );
      return code == null
          ? null
          : AuthorizationCode(code: code, redirectUri: redirectUri);
    } finally {
      await server.close(force: true);
    }
  }

  /// Answers requests until one carries the OAuth result (the browser may ask
  /// for a favicon first), and returns its code when it is a valid grant.
  Future<String?> _awaitRedirect(HttpServer server, String state) async {
    await for (final request in server) {
      final query = request.uri.queryParameters;
      if (!query.containsKey('code') && !query.containsKey('error')) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      final code = query['code'];
      final granted = code != null && query['state'] == state;
      if (!granted) {
        _log.warning(
          'Google sign-in did not complete: '
          '${query['error'] ?? 'state mismatch'}',
        );
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(granted ? _successPage : _failurePage);
      await request.response.close();
      return granted ? code : null;
    }
    return null;
  }

  static const _successPage =
      '<!doctype html><meta charset="utf-8"><title>NovelViewer</title>'
      '<p>ログインしました。NovelViewer に戻ってください。</p>'
      '<p>Signed in. You can return to NovelViewer.</p>';

  static const _failurePage =
      '<!doctype html><meta charset="utf-8"><title>NovelViewer</title>'
      '<p>ログインできませんでした。NovelViewer からやり直してください。</p>'
      '<p>Sign-in did not complete. Please try again from NovelViewer.</p>';
}
