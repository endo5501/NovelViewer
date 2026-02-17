import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  group('fontSizeProvider', () {
    test('initial value is default font size (14.0)', () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(fontSizeProvider), 14.0);
    });

    test('initial value loads from SharedPreferences', () async {
      await prefs.setDouble('font_size', 20.0);
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(fontSizeProvider), 20.0);
    });

    test('previewFontSize updates state without persisting', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(fontSizeProvider.notifier).previewFontSize(24.0);
      expect(container.read(fontSizeProvider), 24.0);
      expect(prefs.getDouble('font_size'), isNull);
    });

    test('persistFontSize saves current state to SharedPreferences', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(fontSizeProvider.notifier).previewFontSize(24.0);
      await container.read(fontSizeProvider.notifier).persistFontSize();
      expect(container.read(fontSizeProvider), 24.0);
      expect(prefs.getDouble('font_size'), 24.0);
    });
  });

  group('columnSpacingProvider', () {
    test('initial value is default column spacing (8.0)', () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(columnSpacingProvider), 8.0);
    });

    test('initial value loads from SharedPreferences', () async {
      await prefs.setDouble('column_spacing', 16.0);
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(columnSpacingProvider), 16.0);
    });

    test('previewColumnSpacing updates state without persisting', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(columnSpacingProvider.notifier).previewColumnSpacing(12.0);
      expect(container.read(columnSpacingProvider), 12.0);
      expect(prefs.getDouble('column_spacing'), isNull);
    });

    test('persistColumnSpacing saves current state to SharedPreferences',
        () async {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(columnSpacingProvider.notifier).previewColumnSpacing(12.0);
      await container
          .read(columnSpacingProvider.notifier)
          .persistColumnSpacing();
      expect(container.read(columnSpacingProvider), 12.0);
      expect(prefs.getDouble('column_spacing'), 12.0);
    });
  });

  group('themeModeProvider', () {
    test('initial value is ThemeMode.light', () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('initial value loads from SharedPreferences', () async {
      await prefs.setString('theme_mode', 'dark');
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('setThemeMode updates state and persists', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('setThemeMode can toggle back to light', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(prefs.getString('theme_mode'), 'light');
    });
  });

  group('fontFamilyProvider', () {
    test('initial value is FontFamily.system', () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(fontFamilyProvider), FontFamily.system);
    });

    test('initial value loads from SharedPreferences', () async {
      await prefs.setString('font_family', 'hiraginoMincho');
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(fontFamilyProvider), FontFamily.hiraginoMincho);
    });

    test('setFontFamily updates state and persists', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container
          .read(fontFamilyProvider.notifier)
          .setFontFamily(FontFamily.yuGothic);
      expect(container.read(fontFamilyProvider), FontFamily.yuGothic);
      expect(prefs.getString('font_family'), 'yuGothic');
    });
  });
}
