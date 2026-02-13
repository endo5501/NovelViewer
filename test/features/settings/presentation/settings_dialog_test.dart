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
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('displays current font size value', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('14.0'), findsOneWidget);
    });

    testWidgets('slider updates font size', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final slider = find.byType(Slider);
      // Drag slider to roughly the middle (range 10-32, midpoint ~21)
      await tester.drag(slider, const Offset(50, 0));
      await tester.pumpAndSettle();

      // Font size should have changed from default
      expect(find.text('14.0'), findsNothing);
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

    testWidgets('dropdown shows all font families', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Tap to open dropdown
      await tester.tap(find.byType(DropdownButton<FontFamily>));
      await tester.pumpAndSettle();

      for (final family in FontFamily.values) {
        expect(find.text(family.displayName), findsWidgets);
      }
    });

    testWidgets('selecting a font family updates the value', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byType(DropdownButton<FontFamily>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ヒラギノ明朝').last);
      await tester.pumpAndSettle();

      expect(find.text('ヒラギノ明朝'), findsOneWidget);
    });
  });
}
