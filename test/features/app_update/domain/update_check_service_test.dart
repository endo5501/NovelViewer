import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/app_update/data/github_release_client.dart';
import 'package:novel_viewer/features/app_update/data/update_preferences.dart';
import 'package:novel_viewer/features/app_update/domain/update_check_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GithubReleaseClient clientReturning(
    String tag, {
    List<Map<String, String>> assets = const [],
  }) {
    final mock = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'tag_name': tag,
          'body': 'notes',
          'assets': assets
              .map((a) => {'name': a['name'], 'browser_download_url': a['url']})
              .toList(),
        }),
        200,
      );
    });
    return GithubReleaseClient(httpClient: mock, userAgent: 'ua');
  }

  GithubReleaseClient failingClient() {
    final mock = MockClient((request) async => http.Response('err', 500));
    return GithubReleaseClient(httpClient: mock, userAgent: 'ua');
  }

  Future<UpdatePreferences> prefs([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    return UpdatePreferences(await SharedPreferences.getInstance());
  }

  UpdateCheckService service({
    required GithubReleaseClient client,
    required UpdatePreferences preferences,
    String currentVersion = '1.0.0',
    bool isDebug = false,
    bool isSupported = true,
    DateTime? now,
  }) {
    return UpdateCheckService(
      releaseClient: client,
      preferences: preferences,
      currentVersion: currentVersion,
      isDebug: isDebug,
      isSupported: isSupported,
      now: () => now ?? DateTime.utc(2026, 5, 28, 12, 0, 0),
    );
  }

  /// A client that fails the test if it is reached at all.
  GithubReleaseClient unreachableClient() {
    final mock = MockClient((request) async {
      fail('the release API was contacted: ${request.url}');
    });
    return GithubReleaseClient(httpClient: mock, userAgent: 'ua');
  }

  group('platforms without a way to update themselves', () {
    test('the auto check contacts nothing and records no attempt', () async {
      final preferences = await prefs();
      final s = service(
        client: unreachableClient(),
        preferences: preferences,
        isSupported: false,
      );

      final result = await s.check();

      expect(result, isA<UpdateSkipped>());
      expect(preferences.lastCheckAt, isNull);
    });

    test('a manual check is refused too', () async {
      final preferences = await prefs();
      final s = service(
        client: unreachableClient(),
        preferences: preferences,
        isSupported: false,
      );

      final result = await s.check(manual: true);

      expect(result, isA<UpdateSkipped>());
      expect(preferences.lastCheckAt, isNull);
    });

    test('the refusal precedes every other condition', () async {
      // Auto-check enabled, not debug, never checked before, a newer release
      // waiting: the only reason to skip is the platform itself.
      final s = service(
        client: unreachableClient(),
        preferences: await prefs({'app_update.auto_check_enabled': true}),
        isSupported: false,
      );

      expect(await s.check(), isA<UpdateSkipped>());
    });

    test('a supported platform still reaches the release API', () async {
      final s = service(
        client: clientReturning('v2.0.0'),
        preferences: await prefs(),
      );

      expect(await s.check(), isA<UpdateAvailable>());
    });
  });

  test('auto check is skipped in debug builds', () async {
    final s = service(
      client: clientReturning('v2.0.0'),
      preferences: await prefs(),
      isDebug: true,
    );
    final result = await s.check();
    expect(result, isA<UpdateSkipped>());
  });

  test('manual check runs even in debug builds', () async {
    final s = service(
      client: clientReturning('v2.0.0'),
      preferences: await prefs(),
      isDebug: true,
    );
    final result = await s.check(manual: true);
    expect(result, isA<UpdateAvailable>());
  });

  test('auto check is skipped when auto-check disabled', () async {
    final s = service(
      client: clientReturning('v2.0.0'),
      preferences: await prefs({'app_update.auto_check_enabled': false}),
    );
    expect(await s.check(), isA<UpdateSkipped>());
  });

  test('auto check is skipped within 24h of last check', () async {
    final now = DateTime.utc(2026, 5, 28, 12, 0, 0);
    final recent = now.subtract(const Duration(hours: 1));
    final s = service(
      client: clientReturning('v2.0.0'),
      preferences: await prefs({
        'app_update.last_check_timestamp': recent.millisecondsSinceEpoch,
      }),
      now: now,
    );
    expect(await s.check(), isA<UpdateSkipped>());
  });

  test('auto check runs after 24h and reports availability', () async {
    final now = DateTime.utc(2026, 5, 28, 12, 0, 0);
    final old = now.subtract(const Duration(hours: 25));
    final p = await prefs({
      'app_update.last_check_timestamp': old.millisecondsSinceEpoch,
    });
    final s = service(
      client: clientReturning('v2.0.0'),
      preferences: p,
      now: now,
    );
    final result = await s.check();
    expect(result, isA<UpdateAvailable>());
    // lastCheckAt is refreshed to "now"
    expect(p.lastCheckAt, now);
  });

  test('reports not available when current is latest', () async {
    final s = service(
      client: clientReturning('v1.0.0'),
      preferences: await prefs(),
    );
    expect(await s.check(manual: true), isA<UpdateNotAvailable>());
  });

  test('snoozed version is suppressed on auto check', () async {
    final s = service(
      client: clientReturning('v2.0.0'),
      preferences: await prefs({'app_update.dismissed_version': '2.0.0'}),
    );
    expect(await s.check(), isA<UpdateNotAvailable>());
  });

  test('snoozed version is still shown on manual check', () async {
    final s = service(
      client: clientReturning('v2.0.0'),
      preferences: await prefs({'app_update.dismissed_version': '2.0.0'}),
    );
    expect(await s.check(manual: true), isA<UpdateAvailable>());
  });

  test('a newer version than the snoozed one is shown', () async {
    final s = service(
      client: clientReturning('v3.0.0'),
      preferences: await prefs({'app_update.dismissed_version': '2.0.0'}),
    );
    expect(await s.check(), isA<UpdateAvailable>());
  });

  test(
    'snooze ignores build metadata (v2.0.0+5 stays snoozed as 2.0.0)',
    () async {
      final s = service(
        client: clientReturning('v2.0.0+5'),
        currentVersion: '1.0.0',
        preferences: await prefs({'app_update.dismissed_version': '2.0.0'}),
      );
      expect(await s.check(), isA<UpdateNotAvailable>());
    },
  );

  test('returns error status when the fetch fails', () async {
    final s = service(client: failingClient(), preferences: await prefs());
    expect(await s.check(manual: true), isA<UpdateCheckError>());
  });
}
