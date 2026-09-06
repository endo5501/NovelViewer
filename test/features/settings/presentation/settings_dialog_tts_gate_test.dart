import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_availability_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The TTS settings tab is the most dangerous surface on a platform without
/// TTS: the voice-reference section builds a `DropTarget` from a plugin that
/// is not registered on iOS, and the recording dialog asks for the microphone.
/// iOS terminates a process that requests the microphone with no usage
/// description in its Info.plist — not an exception the app can catch, an
/// immediate kill. So the tab is not listed and its content is never built.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget build({required bool ttsSupported}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
        ttsSupportedProvider.overrideWithValue(ttsSupported),
        // The about/update tab reads this at build time; without it the tab
        // cannot be opened at all.
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

  testWidgets('the TTS tab is listed where TTS is supported', (tester) async {
    await tester.pumpWidget(build(ttsSupported: true));
    await tester.pumpAndSettle();

    expect(find.text('読み上げ'), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).tabs.length, 3);
  });

  testWidgets('the TTS tab is absent where TTS is unsupported', (tester) async {
    await tester.pumpWidget(build(ttsSupported: false));
    await tester.pumpAndSettle();

    expect(find.text('読み上げ'), findsNothing);
    expect(tester.widget<TabBar>(find.byType(TabBar)).tabs.length, 2);
  });

  testWidgets('the remaining tabs still work where TTS is unsupported', (
    tester,
  ) async {
    await tester.pumpWidget(build(ttsSupported: false));
    await tester.pumpAndSettle();

    // General tab is active by default.
    expect(find.text('縦書き表示'), findsOneWidget);
    expect(find.text('ダークモード'), findsOneWidget);

    // The about/update tab is still reachable, and switching to it does not
    // land on TTS content.
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    await tester.tap(find.text(l10n.settings_aboutUpdateTab));
    await tester.pumpAndSettle();

    expect(find.text('音声モデル'), findsNothing);
  });
}
