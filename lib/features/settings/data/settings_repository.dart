import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/tts/data/piper_model_download_service.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/data/tts_language.dart';
import 'package:novel_viewer/features/tts/data/tts_model_size.dart';

class SettingsRepository {
  static const _localeKey = 'locale';
  static const _displayModeKey = 'text_display_mode';
  static const _fontSizeKey = 'font_size';
  static const _fontFamilyKey = 'font_family';
  static const _columnSpacingKey = 'column_spacing';
  static const _themeModeKey = 'theme_mode';
  static const _llmProviderKey = 'llm_provider';
  static const _llmBaseUrlKey = 'llm_base_url';
  static const _llmApiKeyKey = 'llm_api_key';
  static const _llmModelKey = 'llm_model';
  static const _ttsModelSizeKey = 'tts_model_size';
  static const _ttsRefWavPathKey = 'tts_ref_wav_path';
  static const _ttsLanguageKey = 'tts_language';
  static const _ttsEngineTypeKey = 'tts_engine_type';
  static const _piperModelNameKey = 'piper_model_name';
  static const _piperLengthScaleKey = 'piper_length_scale';
  static const _piperNoiseScaleKey = 'piper_noise_scale';
  static const _piperNoiseWKey = 'piper_noise_w';

  static const defaultFontSize = 14.0;
  static const minFontSize = 10.0;
  static const maxFontSize = 32.0;

  static const defaultColumnSpacing = 8.0;
  static const minColumnSpacing = 0.0;
  static const maxColumnSpacing = 24.0;

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  SettingsRepository(
    this._prefs, {
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const supportedLocales = ['ja', 'en', 'zh'];
  static const defaultLocale = 'ja';

  String getLocale() {
    final value = _prefs.getString(_localeKey);
    if (value != null && supportedLocales.contains(value)) {
      return value;
    }
    return defaultLocale;
  }

  Future<void> setLocale(String locale) async {
    final normalized = supportedLocales.contains(locale) ? locale : defaultLocale;
    await _prefs.setString(_localeKey, normalized);
  }

  TextDisplayMode getDisplayMode() {
    final value = _prefs.getString(_displayModeKey);
    return TextDisplayMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => TextDisplayMode.horizontal,
    );
  }

  Future<void> setDisplayMode(TextDisplayMode mode) async {
    await _prefs.setString(_displayModeKey, mode.name);
  }

  double getFontSize() {
    final value = _prefs.getDouble(_fontSizeKey) ?? defaultFontSize;
    return value.clamp(minFontSize, maxFontSize);
  }

  Future<void> setFontSize(double size) async {
    await _prefs.setDouble(_fontSizeKey, size.clamp(minFontSize, maxFontSize));
  }

  FontFamily getFontFamily() {
    final value = _prefs.getString(_fontFamilyKey);
    return FontFamily.values.firstWhere(
      (family) => family.name == value,
      orElse: () => FontFamily.system,
    );
  }

  Future<void> setFontFamily(FontFamily family) async {
    await _prefs.setString(_fontFamilyKey, family.name);
  }

  double getColumnSpacing() {
    final value = _prefs.getDouble(_columnSpacingKey) ?? defaultColumnSpacing;
    return value.clamp(minColumnSpacing, maxColumnSpacing);
  }

  Future<void> setColumnSpacing(double spacing) async {
    await _prefs.setDouble(
        _columnSpacingKey, spacing.clamp(minColumnSpacing, maxColumnSpacing));
  }

  ThemeMode getThemeMode() {
    final value = _prefs.getString(_themeModeKey);
    return value == ThemeMode.dark.name ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
  }

  LlmConfig getLlmConfig() {
    final providerName = _prefs.getString(_llmProviderKey);
    final provider = LlmProvider.values.firstWhere(
      (p) => p.name == providerName,
      orElse: () => LlmProvider.none,
    );
    return LlmConfig(
      provider: provider,
      baseUrl: _prefs.getString(_llmBaseUrlKey) ?? '',
      model: _prefs.getString(_llmModelKey) ?? '',
    );
  }

  Future<void> setLlmConfig(LlmConfig config) async {
    await _prefs.setString(_llmProviderKey, config.provider.name);
    await _prefs.setString(_llmBaseUrlKey, config.baseUrl);
    await _prefs.setString(_llmModelKey, config.model);
  }

  Future<String> getApiKey() async {
    final value = await _secureStorage.read(key: _llmApiKeyKey);
    return value ?? '';
  }

  Future<void> setApiKey(String apiKey) async {
    if (apiKey.isEmpty) {
      await _secureStorage.delete(key: _llmApiKeyKey);
      return;
    }
    await _secureStorage.write(key: _llmApiKeyKey, value: apiKey);
  }

  /// Migrate any pre-existing `llm_api_key` entry from `SharedPreferences` to
  /// `flutter_secure_storage`. Safe to invoke on every startup: when the
  /// SharedPreferences entry is absent (already migrated, or new install) the
  /// call is a no-op. If the secure-storage write fails (e.g. libsecret
  /// unavailable on Linux), the SharedPreferences entry is preserved so the
  /// migration can be retried on the next startup, and the failure is logged
  /// via [debugPrint] without propagating.
  Future<void> migrateApiKeyToSecureStorage() async {
    final legacyKey = _prefs.getString(_llmApiKeyKey);
    if (legacyKey == null) {
      return;
    }
    try {
      // Don't clobber a key that secure storage already holds — it would be
      // newer than the SharedPreferences leftover (e.g. a prior `prefs.remove`
      // failed, or a future fallback path repopulated SharedPreferences).
      final existing = await _secureStorage.read(key: _llmApiKeyKey);
      if (existing == null || existing.isEmpty) {
        await _secureStorage.write(key: _llmApiKeyKey, value: legacyKey);
      }
    } catch (e, stack) {
      debugPrint('migrateApiKeyToSecureStorage: failed: $e\n$stack');
      return;
    }
    await _prefs.remove(_llmApiKeyKey);
  }

  TtsModelSize getTtsModelSize() {
    final value = _prefs.getString(_ttsModelSizeKey);
    return TtsModelSize.values.firstWhere(
      (size) => size.name == value,
      orElse: () => TtsModelSize.small,
    );
  }

  Future<void> setTtsModelSize(TtsModelSize size) async {
    await _prefs.setString(_ttsModelSizeKey, size.name);
  }

  String getTtsRefWavPath() {
    return _prefs.getString(_ttsRefWavPathKey) ?? '';
  }

  Future<void> setTtsRefWavPath(String path) async {
    await _prefs.setString(_ttsRefWavPathKey, path);
  }

  TtsLanguage getTtsLanguage() {
    final value = _prefs.getString(_ttsLanguageKey);
    return TtsLanguage.values.firstWhere(
      (lang) => lang.name == value,
      orElse: () => TtsLanguage.ja,
    );
  }

  Future<void> setTtsLanguage(TtsLanguage language) async {
    await _prefs.setString(_ttsLanguageKey, language.name);
  }

  // TTS engine type
  TtsEngineType getTtsEngineType() {
    final value = _prefs.getString(_ttsEngineTypeKey);
    return TtsEngineType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TtsEngineType.qwen3,
    );
  }

  Future<void> setTtsEngineType(TtsEngineType type) async {
    await _prefs.setString(_ttsEngineTypeKey, type.name);
  }

  // Piper model name
  static const _legacyPiperModelName = 'ja_JP-tsukuyomi-chan-medium';

  String getPiperModelName() {
    final value = _prefs.getString(_piperModelNameKey);
    if (value == null || value == _legacyPiperModelName) {
      return PiperModelDownloadService.defaultModelName;
    }
    return value;
  }

  Future<void> setPiperModelName(String name) async {
    await _prefs.setString(_piperModelNameKey, name);
  }

  // Piper synthesis parameters
  double getPiperLengthScale() {
    return (_prefs.getDouble(_piperLengthScaleKey) ?? 1.3).clamp(0.5, 2.0);
  }

  Future<void> setPiperLengthScale(double value) async {
    await _prefs.setDouble(_piperLengthScaleKey, value);
  }

  double getPiperNoiseScale() {
    return (_prefs.getDouble(_piperNoiseScaleKey) ?? 0.667).clamp(0.0, 1.0);
  }

  Future<void> setPiperNoiseScale(double value) async {
    await _prefs.setDouble(_piperNoiseScaleKey, value);
  }

  double getPiperNoiseW() {
    return (_prefs.getDouble(_piperNoiseWKey) ?? 0.8).clamp(0.0, 1.0);
  }

  Future<void> setPiperNoiseW(double value) async {
    await _prefs.setDouble(_piperNoiseWKey, value);
  }
}
