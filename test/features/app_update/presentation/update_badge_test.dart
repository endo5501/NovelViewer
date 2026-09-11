import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/app_update/data/release_info.dart';
import 'package:novel_viewer/features/app_update/domain/update_check_service.dart';
import 'package:novel_viewer/features/app_update/presentation/update_badge.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const release = ReleaseInfo(tagName: 'v1.3.0', body: '', assets: []);

  Widget host({required UpdateAvailable? available}) {
    return ProviderScope(
      overrides: [updateAvailableProvider.overrideWithValue(available)],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(appBar: AppBar(actions: const [UpdateBadge()])),
      ),
    );
  }

  testWidgets('shows the badge button when an update is available', (
    tester,
  ) async {
    await tester.pumpWidget(host(available: const UpdateAvailable(release)));
    await tester.pump();

    expect(find.byKey(const Key('update_badge_button')), findsOneWidget);
  });

  testWidgets('hides the badge button when no update is available', (
    tester,
  ) async {
    await tester.pumpWidget(host(available: null));
    await tester.pump();

    expect(find.byKey(const Key('update_badge_button')), findsNothing);
  });

  testWidgets(
    'no badge can appear where the app cannot update itself, because the '
    'check never runs',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      // Counted rather than asserted inside the handler: the service turns any
      // exception from the release client into an UpdateCheckError, so a
      // `fail()` in there would be swallowed and prove nothing.
      var requests = 0;
      final container = ProviderContainer(
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities.forPlatform(isIOS: true, isMacOS: false),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
          packageInfoProvider.overrideWithValue(
            PackageInfo(
              appName: 'NovelViewer',
              packageName: 'com.endo5501.novelViewer',
              version: '1.0.0',
              buildNumber: '1',
            ),
          ),
          httpClientProvider.overrideWithValue(
            MockClient((request) async {
              requests++;
              return http.Response(
                jsonEncode({'tag_name': 'v9.9.9', 'body': '', 'assets': []}),
                200,
              );
            }),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Both entry points: the fire-and-forget check main() performs at
      // startup, and the manual one. The manual check is what discriminates
      // here — an auto check is skipped in a test build anyway, since the
      // test binary reports kDebugMode.
      await container.read(updateStatusProvider.notifier).check();
      await container.read(updateStatusProvider.notifier).check(manual: true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(appBar: AppBar(actions: const [UpdateBadge()])),
          ),
        ),
      );
      await tester.pump();

      expect(requests, 0);
      expect(container.read(updateAvailableProvider), isNull);
      expect(find.byKey(const Key('update_badge_button')), findsNothing);
    },
  );
}
