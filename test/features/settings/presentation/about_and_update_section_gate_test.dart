import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/settings/presentation/sections/about_and_update_section.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSection(
    WidgetTester tester, {
    required bool updateSupported,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appUpdateSupportedProvider.overrideWithValue(updateSupported),
          sharedPreferencesProvider.overrideWithValue(preferences),
          packageInfoProvider.overrideWithValue(
            PackageInfo(
              appName: 'NovelViewer',
              packageName: 'com.endo5501.novelViewer',
              version: '1.8.4',
              buildNumber: '19',
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: AboutAndUpdateSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppLocalizations l10nOf(WidgetTester tester) {
    final context = tester.element(find.byType(AboutAndUpdateSection));
    return AppLocalizations.of(context)!;
  }

  testWidgets('the version is shown whether or not updates are supported', (
    tester,
  ) async {
    for (final supported in [true, false]) {
      await pumpSection(tester, updateSupported: supported);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.settings_currentVersionLabel), findsOneWidget);
      expect(find.text('1.8.4'), findsOneWidget);
      expect(find.text(l10n.settings_buildNumberLabel), findsOneWidget);
      expect(find.text('19'), findsOneWidget);
    }
  });

  testWidgets('every update row is present where updates are supported', (
    tester,
  ) async {
    await pumpSection(tester, updateSupported: true);
    final l10n = l10nOf(tester);

    expect(find.text(l10n.settings_distributionLabel), findsOneWidget);
    expect(find.text(l10n.settings_lastCheckedLabel), findsOneWidget);
    expect(find.text(l10n.settings_checkForUpdatesButton), findsOneWidget);
    expect(find.text(l10n.settings_autoCheckLabel), findsOneWidget);
  });

  testWidgets('every update row is gone where updates are unsupported', (
    tester,
  ) async {
    await pumpSection(tester, updateSupported: false);
    final l10n = l10nOf(tester);

    expect(find.text(l10n.settings_distributionLabel), findsNothing);
    expect(find.text(l10n.settings_lastCheckedLabel), findsNothing);
    expect(find.text(l10n.settings_checkForUpdatesButton), findsNothing);
    expect(find.text(l10n.settings_autoCheckLabel), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets(
    'the distribution type is not even resolved where updates are unsupported',
    (tester) async {
      // Resolving it would read the Windows registry and log a fallback on a
      // platform where the installer/ZIP distinction has no meaning.
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var resolved = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUpdateSupportedProvider.overrideWithValue(false),
            sharedPreferencesProvider.overrideWithValue(preferences),
            packageInfoProvider.overrideWithValue(
              PackageInfo(
                appName: 'NovelViewer',
                packageName: 'com.endo5501.novelViewer',
                version: '1.8.4',
                buildNumber: '19',
              ),
            ),
            distributionTypeProvider.overrideWith((ref) {
              resolved = true;
              throw StateError('distribution type resolved unexpectedly');
            }),
          ],
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: AboutAndUpdateSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(resolved, isFalse);
      expect(find.text('1.8.4'), findsOneWidget);
    },
  );
}
