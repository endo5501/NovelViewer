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

  GithubReleaseClient clientReturning(String tag,
      {List<Map<String, String>> assets = const []}) {
    final mock = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'tag_name': tag,
          'body': 'notes',
          'assets': assets
              .map((a) => {
                    'name': a['name'],
                    'browser_download_url': a['url'],
                  })
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

  Future<UpdatePreferences> prefs([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return UpdatePreferences(await SharedPreferences.getInstance());
  }

  UpdateCheckService service({
    required GithubReleaseClient client,
    required UpdatePreferences preferences,
    String currentVersion = '1.0.0',
    bool isDebug = false,
    DateTime? now,
  }) {
    return UpdateCheckService(
      releaseClient: client,
      preferences: preferences,
      currentVersion: currentVersion,
      isDebug: isDebug,
      now: () => now ?? DateTime.utc(2026, 5, 28, 12, 0, 0),
    );
  }

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

  test('snooze ignores build metadata (v2.0.0+5 stays snoozed as 2.0.0)',
      () async {
    final s = service(
      client: clientReturning('v2.0.0+5'),
      currentVersion: '1.0.0',
      preferences: await prefs({'app_update.dismissed_version': '2.0.0'}),
    );
    expect(await s.check(), isA<UpdateNotAvailable>());
  });

  test('returns error status when the fetch fails', () async {
    final s = service(
      client: failingClient(),
      preferences: await prefs(),
    );
    expect(await s.check(manual: true), isA<UpdateCheckError>());
  });
}
