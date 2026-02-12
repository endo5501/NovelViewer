import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';

class SettingsRepository {
  static const _displayModeKey = 'text_display_mode';

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
}
