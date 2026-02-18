import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';

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

  group('SettingsRepository - column spacing', () {
    test('getColumnSpacing returns default 8.0 when no value stored', () {
      final repo = SettingsRepository(prefs);
      expect(repo.getColumnSpacing(), 8.0);
    });

    test('setColumnSpacing and getColumnSpacing round-trip', () async {
      final repo = SettingsRepository(prefs);
      await repo.setColumnSpacing(12.0);
      expect(repo.getColumnSpacing(), 12.0);
    });

    test('getColumnSpacing clamps value below minimum to 0.0', () async {
      await prefs.setDouble('column_spacing', -5.0);
      final repo = SettingsRepository(prefs);
      expect(repo.getColumnSpacing(), 0.0);
    });

    test('getColumnSpacing clamps value above maximum to 24.0', () async {
      await prefs.setDouble('column_spacing', 50.0);
      final repo = SettingsRepository(prefs);
      expect(repo.getColumnSpacing(), 24.0);
    });

    test('setColumnSpacing clamps value to valid range', () async {
      final repo = SettingsRepository(prefs);
      await repo.setColumnSpacing(-1.0);
      expect(repo.getColumnSpacing(), 0.0);

      await repo.setColumnSpacing(30.0);
      expect(repo.getColumnSpacing(), 24.0);
    });
  });

  group('SettingsRepository - theme mode', () {
    test('getThemeMode returns ThemeMode.light when no value stored', () {
      final repo = SettingsRepository(prefs);
      expect(repo.getThemeMode(), ThemeMode.light);
    });

    test('setThemeMode and getThemeMode round-trip for dark', () async {
      final repo = SettingsRepository(prefs);
      await repo.setThemeMode(ThemeMode.dark);
      expect(repo.getThemeMode(), ThemeMode.dark);
    });

    test('setThemeMode and getThemeMode round-trip for light', () async {
      final repo = SettingsRepository(prefs);
      await repo.setThemeMode(ThemeMode.dark);
      await repo.setThemeMode(ThemeMode.light);
      expect(repo.getThemeMode(), ThemeMode.light);
    });

    test('getThemeMode returns light for invalid stored value', () async {
      await prefs.setString('theme_mode', 'invalid');
      final repo = SettingsRepository(prefs);
      expect(repo.getThemeMode(), ThemeMode.light);
    });

    test('getThemeMode returns light when system is stored', () async {
      await prefs.setString('theme_mode', 'system');
      final repo = SettingsRepository(prefs);
      expect(repo.getThemeMode(), ThemeMode.light);
    });
  });

  group('SettingsRepository - LLM config', () {
    test('getLlmConfig returns default none config when no value stored', () {
      final repo = SettingsRepository(prefs);
      final config = repo.getLlmConfig();
      expect(config.provider, LlmProvider.none);
      expect(config.baseUrl, '');
      expect(config.apiKey, '');
      expect(config.model, '');
    });

    test('setLlmConfig and getLlmConfig round-trip for OpenAI', () async {
      final repo = SettingsRepository(prefs);
      const config = LlmConfig(
        provider: LlmProvider.openai,
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
        model: 'gpt-4o-mini',
      );
      await repo.setLlmConfig(config);
      final loaded = repo.getLlmConfig();
      expect(loaded.provider, LlmProvider.openai);
      expect(loaded.baseUrl, 'https://api.openai.com/v1');
      expect(loaded.apiKey, 'sk-test');
      expect(loaded.model, 'gpt-4o-mini');
    });

    test('setLlmConfig and getLlmConfig round-trip for Ollama', () async {
      final repo = SettingsRepository(prefs);
      const config = LlmConfig(
        provider: LlmProvider.ollama,
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
      );
      await repo.setLlmConfig(config);
      final loaded = repo.getLlmConfig();
      expect(loaded.provider, LlmProvider.ollama);
      expect(loaded.baseUrl, 'http://localhost:11434');
      expect(loaded.apiKey, '');
      expect(loaded.model, 'llama3');
    });

    test('getLlmConfig returns none for invalid provider value', () async {
      await prefs.setString('llm_provider', 'invalid');
      final repo = SettingsRepository(prefs);
      final config = repo.getLlmConfig();
      expect(config.provider, LlmProvider.none);
    });
  });

  group('SettingsRepository - TTS settings', () {
    test('getTtsModelDir returns empty string when no value stored', () {
      final repo = SettingsRepository(prefs);
      expect(repo.getTtsModelDir(), '');
    });

    test('setTtsModelDir and getTtsModelDir round-trip', () async {
      final repo = SettingsRepository(prefs);
      await repo.setTtsModelDir('/path/to/models');
      expect(repo.getTtsModelDir(), '/path/to/models');
    });

    test('getTtsRefWavPath returns empty string when no value stored', () {
      final repo = SettingsRepository(prefs);
      expect(repo.getTtsRefWavPath(), '');
    });

    test('setTtsRefWavPath and getTtsRefWavPath round-trip', () async {
      final repo = SettingsRepository(prefs);
      await repo.setTtsRefWavPath('/path/to/ref.wav');
      expect(repo.getTtsRefWavPath(), '/path/to/ref.wav');
    });

    test('clearing TTS model dir sets empty string', () async {
      final repo = SettingsRepository(prefs);
      await repo.setTtsModelDir('/path/to/models');
      await repo.setTtsModelDir('');
      expect(repo.getTtsModelDir(), '');
    });

    test('TTS settings persist independently', () async {
      final repo = SettingsRepository(prefs);
      await repo.setTtsModelDir('/models');
      await repo.setTtsRefWavPath('/ref.wav');
      expect(repo.getTtsModelDir(), '/models');
      expect(repo.getTtsRefWavPath(), '/ref.wav');
    });
  });
}
