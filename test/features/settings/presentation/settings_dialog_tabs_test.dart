import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_language.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
      ],
      child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SettingsDialog()),
      ),
    );
  }

  group('SettingsDialog - tabs', () {
    testWidgets('displays two tabs: 一般 and 読み上げ', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('一般'), findsOneWidget);
      expect(find.text('読み上げ'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('一般 tab shows existing settings by default', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // General tab is active by default - existing settings visible
      expect(find.text('縦書き表示'), findsOneWidget);
      expect(find.text('ダークモード'), findsOneWidget);
      expect(find.text('フォントサイズ'), findsOneWidget);
    });

    testWidgets('読み上げ tab shows TTS settings', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Switch to TTS tab
      await tester.tap(find.text('読み上げ'));
      await tester.pumpAndSettle();

      expect(find.text('音声モデル'), findsOneWidget);
      expect(find.text('リファレンス音声ファイル'), findsOneWidget);
    });

    testWidgets('switching tabs hides other tab content', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Switch to TTS tab
      await tester.tap(find.text('読み上げ'));
      await tester.pumpAndSettle();

      // General settings should not be visible
      expect(find.text('縦書き表示'), findsNothing);
      expect(find.text('ダークモード'), findsNothing);
    });

    testWidgets('TTS tab shows model selector and voice reference controls',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('読み上げ'));
      await tester.pumpAndSettle();

      // Model size selector
      expect(find.text('高速 (0.6B)'), findsOneWidget);
      expect(find.text('高精度 (1.7B)'), findsOneWidget);
      // Voices folder open button only (model dir field removed)
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
      // Voice reference dropdown and refresh button
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('TTS tab shows language dropdown with default Japanese',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('読み上げ'));
      await tester.pumpAndSettle();

      expect(find.text('読み上げ言語'), findsOneWidget);
      // Japanese is the default displayed value
      expect(find.text('日本語'), findsOneWidget);
    });

    testWidgets('language dropdown changes provider value',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('読み上げ'));
      await tester.pumpAndSettle();

      // Open the language dropdown
      await tester.tap(find.text('日本語'));
      await tester.pumpAndSettle();

      // Select English
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      // Verify the provider was updated
      final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsDialog)));
      expect(container.read(ttsLanguageProvider), TtsLanguage.en);
    });

    testWidgets('language dropdown is above model size selector',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('読み上げ'));
      await tester.pumpAndSettle();

      // Language label should be above model label
      final languageY = tester.getTopLeft(find.text('読み上げ言語')).dy;
      final modelY = tester.getTopLeft(find.text('音声モデル')).dy;
      expect(languageY, lessThan(modelY));
    });
  });
}
