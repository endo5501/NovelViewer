import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/presentation/shortcut_settings_section.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/settings/presentation/sections/general_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/llm_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The LLM section configures a server the reader runs themselves, reached by
/// default over plaintext HTTP. iOS blocks that transport outright, so nothing
/// entered here could ever connect; the section is withheld rather than shown
/// as a form whose every setting fails.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget build({required bool llmSupported}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
        llmSummarySupportedProvider.overrideWithValue(llmSupported),
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

  testWidgets('the LLM section is present where LLM summary is supported', (
    tester,
  ) async {
    await tester.pumpWidget(build(llmSupported: true));
    await tester.pumpAndSettle();

    expect(find.byType(LlmSettingsSection), findsOneWidget);
  });

  testWidgets('the LLM section is absent where LLM summary is unsupported', (
    tester,
  ) async {
    await tester.pumpWidget(build(llmSupported: false));
    await tester.pumpAndSettle();

    expect(find.byType(LlmSettingsSection), findsNothing);
  });

  testWidgets('the remaining general-tab sections are unaffected', (
    tester,
  ) async {
    await tester.pumpWidget(build(llmSupported: false));
    await tester.pumpAndSettle();

    expect(find.byType(GeneralSettingsSection), findsOneWidget);
    expect(find.byType(ShortcutSettingsSection), findsOneWidget);
  });

  testWidgets('no separator is left dangling below the last section', (
    tester,
  ) async {
    await tester.pumpWidget(build(llmSupported: true));
    await tester.pumpAndSettle();
    final withLlm = tester.widgetList(find.byType(Divider)).length;

    await tester.pumpWidget(build(llmSupported: false));
    await tester.pumpAndSettle();
    final withoutLlm = tester.widgetList(find.byType(Divider)).length;

    // Removing the last section removes the separator that preceded it.
    expect(withoutLlm, withLlm - 1);
  });
}
