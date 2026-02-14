import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_config.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';

class SettingsRepository {
  static const _displayModeKey = 'text_display_mode';
  static const _fontSizeKey = 'font_size';
  static const _fontFamilyKey = 'font_family';
  static const _llmProviderKey = 'llm_provider';
  static const _llmBaseUrlKey = 'llm_base_url';
  static const _llmApiKeyKey = 'llm_api_key';
  static const _llmModelKey = 'llm_model';

  static const defaultFontSize = 14.0;
  static const minFontSize = 10.0;
  static const maxFontSize = 32.0;

  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

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

  LlmConfig getLlmConfig() {
    final providerName = _prefs.getString(_llmProviderKey);
    final provider = LlmProvider.values.firstWhere(
      (p) => p.name == providerName,
      orElse: () => LlmProvider.none,
    );
    return LlmConfig(
      provider: provider,
      baseUrl: _prefs.getString(_llmBaseUrlKey) ?? '',
      apiKey: _prefs.getString(_llmApiKeyKey) ?? '',
      model: _prefs.getString(_llmModelKey) ?? '',
    );
  }

  Future<void> setLlmConfig(LlmConfig config) async {
    await _prefs.setString(_llmProviderKey, config.provider.name);
    await _prefs.setString(_llmBaseUrlKey, config.baseUrl);
    await _prefs.setString(_llmApiKeyKey, config.apiKey);
    await _prefs.setString(_llmModelKey, config.model);
  }
}
