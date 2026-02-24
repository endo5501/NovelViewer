import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

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
      child: const MaterialApp(
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

      expect(find.text('モデルディレクトリ'), findsOneWidget);
      expect(find.text('リファレンスWAVファイル'), findsOneWidget);
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

    testWidgets('TTS tab shows folder picker button for model dir',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('読み上げ'));
      await tester.pumpAndSettle();

      // Should have folder/file picker buttons
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets('TTS tab shows file picker button for WAV', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('読み上げ'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.audio_file), findsOneWidget);
    });
  });
}
