import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/tts/data/tts_language.dart';
import 'package:novel_viewer/features/tts/data/tts_model_size.dart';

import '../../../test_utils/flutter_secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FlutterSecureStorageMock secureStorageMock;
  late FlutterSecureStorage secureStorage;

  SettingsRepository buildRepo() =>
      SettingsRepository(prefs, secureStorage: secureStorage);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    secureStorageMock = FlutterSecureStorageMock();
    secureStorageMock.install();
    secureStorage = const FlutterSecureStorage();
  });

  tearDown(() {
    secureStorageMock.uninstall();
  });

  group('SettingsRepository - font size', () {
    test('getFontSize returns default 14.0 when no value stored', () {
      final repo = buildRepo();
      expect(repo.getFontSize(), 14.0);
    });

    test('setFontSize and getFontSize round-trip', () async {
      final repo = buildRepo();
      await repo.setFontSize(20.0);
      expect(repo.getFontSize(), 20.0);
    });

    test('getFontSize clamps value below minimum to 10.0', () async {
      await prefs.setDouble('font_size', 5.0);
      final repo = buildRepo();
      expect(repo.getFontSize(), 10.0);
    });

    test('getFontSize clamps value above maximum to 32.0', () async {
      await prefs.setDouble('font_size', 50.0);
      final repo = buildRepo();
      expect(repo.getFontSize(), 32.0);
    });

    test('setFontSize clamps value to valid range', () async {
      final repo = buildRepo();
      await repo.setFontSize(5.0);
      expect(repo.getFontSize(), 10.0);

      await repo.setFontSize(50.0);
      expect(repo.getFontSize(), 32.0);
    });
  });

  group('SettingsRepository - font family', () {
    test('getFontFamily returns system when no value stored', () {
      final repo = buildRepo();
      expect(repo.getFontFamily(), FontFamily.system);
    });

    test('setFontFamily and getFontFamily round-trip', () async {
      final repo = buildRepo();
      await repo.setFontFamily(FontFamily.hiraginoMincho);
      expect(repo.getFontFamily(), FontFamily.hiraginoMincho);
    });

    test('getFontFamily returns system for invalid stored value', () async {
      await prefs.setString('font_family', 'nonexistent_font');
      final repo = buildRepo();
      expect(repo.getFontFamily(), FontFamily.system);
    });

    test('setFontFamily and getFontFamily work for all values', () async {
      final repo = buildRepo();
      for (final family in FontFamily.values) {
        await repo.setFontFamily(family);
        expect(repo.getFontFamily(), family);
      }
    });
  });

  group('SettingsRepository - column spacing', () {
    test('getColumnSpacing returns default 8.0 when no value stored', () {
      final repo = buildRepo();
      expect(repo.getColumnSpacing(), 8.0);
    });

    test('setColumnSpacing and getColumnSpacing round-trip', () async {
      final repo = buildRepo();
      await repo.setColumnSpacing(12.0);
      expect(repo.getColumnSpacing(), 12.0);
    });

    test('getColumnSpacing clamps value below minimum to 0.0', () async {
      await prefs.setDouble('column_spacing', -5.0);
      final repo = buildRepo();
      expect(repo.getColumnSpacing(), 0.0);
    });

    test('getColumnSpacing clamps value above maximum to 24.0', () async {
      await prefs.setDouble('column_spacing', 50.0);
      final repo = buildRepo();
      expect(repo.getColumnSpacing(), 24.0);
    });

    test('setColumnSpacing clamps value to valid range', () async {
      final repo = buildRepo();
      await repo.setColumnSpacing(-1.0);
      expect(repo.getColumnSpacing(), 0.0);

      await repo.setColumnSpacing(30.0);
      expect(repo.getColumnSpacing(), 24.0);
    });
  });

  group('SettingsRepository - theme mode', () {
    test('getThemeMode returns ThemeMode.light when no value stored', () {
      final repo = buildRepo();
      expect(repo.getThemeMode(), ThemeMode.light);
    });

    test('setThemeMode and getThemeMode round-trip for dark', () async {
      final repo = buildRepo();
      await repo.setThemeMode(ThemeMode.dark);
      expect(repo.getThemeMode(), ThemeMode.dark);
    });

    test('setThemeMode and getThemeMode round-trip for light', () async {
      final repo = buildRepo();
      await repo.setThemeMode(ThemeMode.dark);
      await repo.setThemeMode(ThemeMode.light);
      expect(repo.getThemeMode(), ThemeMode.light);
    });

    test('getThemeMode returns light for invalid stored value', () async {
      await prefs.setString('theme_mode', 'invalid');
      final repo = buildRepo();
      expect(repo.getThemeMode(), ThemeMode.light);
    });

    test('getThemeMode returns light when system is stored', () async {
      await prefs.setString('theme_mode', 'system');
      final repo = buildRepo();
      expect(repo.getThemeMode(), ThemeMode.light);
    });
  });

  group('SettingsRepository - LLM config', () {
    test('getLlmConfig returns default none config when no value stored', () {
      final repo = buildRepo();
      final config = repo.getLlmConfig();
      expect(config.provider, LlmProvider.none);
      expect(config.baseUrl, '');
      expect(config.model, '');
    });

    test('setLlmConfig and getLlmConfig round-trip for OpenAI', () async {
      final repo = buildRepo();
      const config = LlmConfig(
        provider: LlmProvider.openai,
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
      );
      await repo.setLlmConfig(config);
      final loaded = repo.getLlmConfig();
      expect(loaded.provider, LlmProvider.openai);
      expect(loaded.baseUrl, 'https://api.openai.com/v1');
      expect(loaded.model, 'gpt-4o-mini');
    });

    test('setLlmConfig and getLlmConfig round-trip for Ollama', () async {
      final repo = buildRepo();
      const config = LlmConfig(
        provider: LlmProvider.ollama,
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
      );
      await repo.setLlmConfig(config);
      final loaded = repo.getLlmConfig();
      expect(loaded.provider, LlmProvider.ollama);
      expect(loaded.baseUrl, 'http://localhost:11434');
      expect(loaded.model, 'llama3');
    });

    test('getLlmConfig returns none for invalid provider value', () async {
      await prefs.setString('llm_provider', 'invalid');
      final repo = buildRepo();
      final config = repo.getLlmConfig();
      expect(config.provider, LlmProvider.none);
    });

    test('setLlmConfig does not write API key into SharedPreferences',
        () async {
      final repo = buildRepo();
      const config = LlmConfig(
        provider: LlmProvider.openai,
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
      );
      await repo.setLlmConfig(config);
      expect(prefs.containsKey('llm_api_key'), isFalse);
    });
  });

  group('SettingsRepository - API key (secure storage)', () {
    test('getApiKey returns empty string when nothing stored', () async {
      final repo = buildRepo();
      expect(await repo.getApiKey(), '');
    });

    test('getApiKey reads value from flutter_secure_storage', () async {
      secureStorageMock.store['llm_api_key'] = 'sk-from-secure';
      final repo = buildRepo();
      expect(await repo.getApiKey(), 'sk-from-secure');
    });

    test('setApiKey writes to flutter_secure_storage, not SharedPreferences',
        () async {
      final repo = buildRepo();
      await repo.setApiKey('sk-test-key');
      expect(secureStorageMock.store['llm_api_key'], 'sk-test-key');
      expect(prefs.containsKey('llm_api_key'), isFalse);
    });

    test('setApiKey with empty string deletes the secure storage entry',
        () async {
      secureStorageMock.store['llm_api_key'] = 'sk-existing';
      final repo = buildRepo();
      await repo.setApiKey('');
      expect(secureStorageMock.store.containsKey('llm_api_key'), isFalse);
    });
  });

  group('SettingsRepository - migrateApiKeyToSecureStorage', () {
    test(
        'transfers an existing SharedPreferences key into secure storage and '
        'removes the SharedPreferences entry', () async {
      await prefs.setString('llm_api_key', 'sk-legacy');
      final repo = buildRepo();

      await repo.migrateApiKeyToSecureStorage();

      expect(secureStorageMock.store['llm_api_key'], 'sk-legacy');
      expect(prefs.containsKey('llm_api_key'), isFalse);
    });

    test('does nothing when SharedPreferences has no llm_api_key entry',
        () async {
      final repo = buildRepo();

      await repo.migrateApiKeyToSecureStorage();

      expect(secureStorageMock.store.containsKey('llm_api_key'), isFalse);
      expect(prefs.containsKey('llm_api_key'), isFalse);
    });

    test('is idempotent: a second invocation is a no-op', () async {
      await prefs.setString('llm_api_key', 'sk-legacy');
      final repo = buildRepo();

      await repo.migrateApiKeyToSecureStorage();
      // Mutate secure storage between calls to ensure the second call doesn't
      // overwrite it from a (now-empty) SharedPreferences source.
      secureStorageMock.store['llm_api_key'] = 'sk-rotated-later';
      await repo.migrateApiKeyToSecureStorage();

      expect(secureStorageMock.store['llm_api_key'], 'sk-rotated-later');
      expect(prefs.containsKey('llm_api_key'), isFalse);
    });

    test(
        'preserves the existing secure storage value when both stores have '
        'a key (e.g. a previous prefs.remove failed) and clears the legacy '
        'SharedPreferences entry', () async {
      await prefs.setString('llm_api_key', 'sk-stale-legacy');
      secureStorageMock.store['llm_api_key'] = 'sk-current-secure';
      final repo = buildRepo();

      await repo.migrateApiKeyToSecureStorage();

      expect(secureStorageMock.store['llm_api_key'], 'sk-current-secure');
      expect(prefs.containsKey('llm_api_key'), isFalse);
    });

    test(
        'leaves the SharedPreferences entry intact and does not throw '
        'when the secure storage write fails', () async {
      await prefs.setString('llm_api_key', 'sk-legacy');
      secureStorageMock.forceWriteFailure = true;
      final repo = buildRepo();

      await repo.migrateApiKeyToSecureStorage();

      expect(prefs.getString('llm_api_key'), 'sk-legacy');
      expect(secureStorageMock.store.containsKey('llm_api_key'), isFalse);
    });
  });

  group('SettingsRepository - TTS settings', () {
    test('getTtsModelSize returns small when no value stored', () {
      final repo = buildRepo();
      expect(repo.getTtsModelSize(), TtsModelSize.small);
    });

    test('setTtsModelSize and getTtsModelSize round-trip', () async {
      final repo = buildRepo();
      await repo.setTtsModelSize(TtsModelSize.large);
      expect(repo.getTtsModelSize(), TtsModelSize.large);
    });

    test('getTtsModelSize returns small for invalid stored value', () async {
      await prefs.setString('tts_model_size', 'invalid');
      final repo = buildRepo();
      expect(repo.getTtsModelSize(), TtsModelSize.small);
    });

    test('getTtsRefWavPath returns empty string when no value stored', () {
      final repo = buildRepo();
      expect(repo.getTtsRefWavPath(), '');
    });

    test('setTtsRefWavPath and getTtsRefWavPath round-trip', () async {
      final repo = buildRepo();
      await repo.setTtsRefWavPath('/path/to/ref.wav');
      expect(repo.getTtsRefWavPath(), '/path/to/ref.wav');
    });

    test('TTS settings persist independently', () async {
      final repo = buildRepo();
      await repo.setTtsModelSize(TtsModelSize.large);
      await repo.setTtsRefWavPath('/ref.wav');
      expect(repo.getTtsModelSize(), TtsModelSize.large);
      expect(repo.getTtsRefWavPath(), '/ref.wav');
    });

    test('getTtsLanguage returns ja when no value stored', () {
      final repo = buildRepo();
      expect(repo.getTtsLanguage(), TtsLanguage.ja);
    });

    test('setTtsLanguage and getTtsLanguage round-trip', () async {
      final repo = buildRepo();
      await repo.setTtsLanguage(TtsLanguage.en);
      expect(repo.getTtsLanguage(), TtsLanguage.en);
    });

    test('getTtsLanguage returns ja for invalid stored value', () async {
      await prefs.setString('tts_language', 'invalid');
      final repo = buildRepo();
      expect(repo.getTtsLanguage(), TtsLanguage.ja);
    });
  });
}
