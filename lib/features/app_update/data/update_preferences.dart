import 'package:shared_preferences/shared_preferences.dart';

/// Persists update-check state: last check time (for rate limiting), the
/// snoozed version (the "Later" choice), and the auto-check toggle.
class UpdatePreferences {
  UpdatePreferences(this._prefs);

  static const _lastCheckKey = 'app_update.last_check_timestamp';
  static const _dismissedVersionKey = 'app_update.dismissed_version';
  static const _autoCheckEnabledKey = 'app_update.auto_check_enabled';

  final SharedPreferences _prefs;

  bool get autoCheckEnabled => _prefs.getBool(_autoCheckEnabledKey) ?? true;

  Future<void> setAutoCheckEnabled(bool value) =>
      _prefs.setBool(_autoCheckEnabledKey, value);

  DateTime? get lastCheckAt {
    final millis = _prefs.getInt(_lastCheckKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> setLastCheckAt(DateTime value) =>
      _prefs.setInt(_lastCheckKey, value.toUtc().millisecondsSinceEpoch);

  String? get dismissedVersion => _prefs.getString(_dismissedVersionKey);

  Future<void> setDismissedVersion(String version) =>
      _prefs.setString(_dismissedVersionKey, version);
}
