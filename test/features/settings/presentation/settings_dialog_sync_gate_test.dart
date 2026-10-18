import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/progress_sync_auth.dart';
import 'package:novel_viewer/features/progress_sync/presentation/sync_settings_section.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_config_providers.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_settings_providers.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_availability_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _shellPath = 'lib/features/settings/presentation/settings_dialog.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget build({required bool syncAvailable}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
        ttsSupportedProvider.overrideWithValue(true),
        progressSyncAvailableProvider.overrideWithValue(syncAvailable),
        syncAccountStateProvider.overrideWithValue(
          const SyncAccountState.signedOut(),
        ),
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
        home: Scaffold(body: SettingsDialog()),
      ),
    );
  }

  testWidgets('the sync tab is listed where sync is available', (
    tester,
  ) async {
    await tester.pumpWidget(build(syncAvailable: true));
    await tester.pumpAndSettle();

    expect(tester.widget<TabBar>(find.byType(TabBar)).tabs.length, 4);
    await tester.tap(find.text('同期'));
    await tester.pumpAndSettle();
    expect(find.byType(SyncSettingsSection), findsOneWidget);
  });

  testWidgets('the sync tab is absent where sync is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(build(syncAvailable: false));
    await tester.pumpAndSettle();

    expect(find.text('同期'), findsNothing);
    expect(tester.widget<TabBar>(find.byType(TabBar)).tabs.length, 3);
  });

  test('the shell stays within 200 lines', () {
    expect(File(_shellPath).readAsLinesSync().length, lessThanOrEqualTo(200));
  });

  test('the shell holds no sync state', () {
    final source = File(_shellPath).readAsStringSync();
    expect(source, isNot(contains('syncAccount')));
    expect(source, isNot(contains('signingIn')));
    expect(source, isNot(contains('SyncRunStatus')));
  });
}
