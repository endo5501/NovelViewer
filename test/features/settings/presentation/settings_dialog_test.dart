import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
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
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(
        home: Scaffold(body: SettingsDialog()),
      ),
    );
  }

  group('SettingsDialog - font size slider', () {
    testWidgets('displays font size slider', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('フォントサイズ'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
    });

    testWidgets('displays current font size value', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('14.0'), findsOneWidget);
    });

    testWidgets('slider updates font size', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final sliders = find.byType(Slider);
      // First slider is font size
      await tester.drag(sliders.first, const Offset(50, 0));
      await tester.pumpAndSettle();

      // Font size should have changed from default
      expect(find.text('14.0'), findsNothing);
    });
  });

  group('SettingsDialog - column spacing slider', () {
    testWidgets('displays column spacing slider', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('列間隔'), findsOneWidget);
    });

    testWidgets('displays current column spacing value', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('8.0'), findsOneWidget);
    });

    testWidgets('slider updates column spacing', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final sliders = find.byType(Slider);
      // Second slider is column spacing
      await tester.drag(sliders.at(1), const Offset(50, 0));
      await tester.pumpAndSettle();

      // Column spacing should have changed from default
      expect(find.text('8.0'), findsNothing);
    });
  });

  group('SettingsDialog - dark mode toggle', () {
    testWidgets('displays dark mode toggle', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('ダークモード'), findsOneWidget);
    });

    testWidgets('dark mode toggle is off by default', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final switchTiles = find.byType(SwitchListTile);
      // Find the dark mode switch (second SwitchListTile after vertical display)
      final darkModeSwitch =
          tester.widget<SwitchListTile>(switchTiles.at(1));
      expect(darkModeSwitch.value, isFalse);
    });

    testWidgets('toggling dark mode updates theme mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Tap the dark mode toggle
      final darkModeSwitch = find.byType(SwitchListTile).at(1);
      await tester.tap(darkModeSwitch);
      await tester.pumpAndSettle();

      // Verify it's now on
      final updatedSwitch =
          tester.widget<SwitchListTile>(find.byType(SwitchListTile).at(1));
      expect(updatedSwitch.value, isTrue);
      expect(prefs.getString('theme_mode'), 'dark');
    });
  });

  group('SettingsDialog - font family dropdown', () {
    testWidgets('displays font family dropdown', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('フォント種別'), findsOneWidget);
      expect(find.byType(DropdownButton<FontFamily>), findsOneWidget);
    });

    testWidgets('displays default font family (system)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('システムデフォルト'), findsOneWidget);
    });

    testWidgets('dropdown shows available font families', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Tap to open dropdown
      await tester.tap(find.byType(DropdownButton<FontFamily>));
      await tester.pumpAndSettle();

      for (final family in FontFamily.availableFonts) {
        expect(find.text(family.displayName), findsWidgets);
      }
    });

    testWidgets('selecting a font family updates the value', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byType(DropdownButton<FontFamily>));
      await tester.pumpAndSettle();

      // Select the last available font (platform-safe)
      final lastFont = FontFamily.availableFonts.last;
      await tester.tap(find.text(lastFont.displayName).last);
      await tester.pumpAndSettle();

      expect(find.text(lastFont.displayName), findsOneWidget);
    });
  });
}
