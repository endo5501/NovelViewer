import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('SettingsRepository - font size', () {
    test('getFontSize returns default 14.0 when no value stored', () {
      final repo = SettingsRepository(prefs);
      expect(repo.getFontSize(), 14.0);
    });

    test('setFontSize and getFontSize round-trip', () async {
      final repo = SettingsRepository(prefs);
      await repo.setFontSize(20.0);
      expect(repo.getFontSize(), 20.0);
    });

    test('getFontSize clamps value below minimum to 10.0', () async {
      await prefs.setDouble('font_size', 5.0);
      final repo = SettingsRepository(prefs);
      expect(repo.getFontSize(), 10.0);
    });

    test('getFontSize clamps value above maximum to 32.0', () async {
      await prefs.setDouble('font_size', 50.0);
      final repo = SettingsRepository(prefs);
      expect(repo.getFontSize(), 32.0);
    });

    test('setFontSize clamps value to valid range', () async {
      final repo = SettingsRepository(prefs);
      await repo.setFontSize(5.0);
      expect(repo.getFontSize(), 10.0);

      await repo.setFontSize(50.0);
      expect(repo.getFontSize(), 32.0);
    });
  });

  group('SettingsRepository - font family', () {
    test('getFontFamily returns system when no value stored', () {
      final repo = SettingsRepository(prefs);
      expect(repo.getFontFamily(), FontFamily.system);
    });

    test('setFontFamily and getFontFamily round-trip', () async {
      final repo = SettingsRepository(prefs);
      await repo.setFontFamily(FontFamily.hiraginoMincho);
      expect(repo.getFontFamily(), FontFamily.hiraginoMincho);
    });

    test('getFontFamily returns system for invalid stored value', () async {
      await prefs.setString('font_family', 'nonexistent_font');
      final repo = SettingsRepository(prefs);
      expect(repo.getFontFamily(), FontFamily.system);
    });

    test('setFontFamily and getFontFamily work for all values', () async {
      final repo = SettingsRepository(prefs);
      for (final family in FontFamily.values) {
        await repo.setFontFamily(family);
        expect(repo.getFontFamily(), family);
      }
    });
  });
}
