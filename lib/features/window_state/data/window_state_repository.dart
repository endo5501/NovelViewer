import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/window_state/domain/window_state.dart';

final _log = Logger('window_state');

/// Reads and writes the main window geometry in [SharedPreferences].
///
/// Deliberately separate from `SettingsRepository`: this is implicit UI state
/// with no settings-screen surface, not a user-facing preference.
class WindowStateRepository {
  static const widthKey = 'window_width';
  static const heightKey = 'window_height';
  static const maximizedKey = 'window_maximized';

  final SharedPreferences _prefs;

  WindowStateRepository(this._prefs);

  /// Returns [WindowState.empty] when nothing usable is stored. A size is only
  /// reported when both axes are present, positive and finite; anything else is
  /// treated as absent so the caller falls back to the default size.
  WindowState load() {
    final double? width;
    final double? height;
    final bool? maximized;
    try {
      // getDouble/getBool throw when the key holds another type, which can
      // happen if an older build (or a hand-edited store) wrote something else.
      width = _prefs.getDouble(widthKey);
      height = _prefs.getDouble(heightKey);
      maximized = _prefs.getBool(maximizedKey);
    } catch (e, stack) {
      _log.warning('Stored window state has an unexpected type; ignoring', e,
          stack);
      return WindowState.empty;
    }

    if (!_isUsable(width) || !_isUsable(height)) {
      return WindowState(maximized: maximized ?? false);
    }
    return WindowState(
      width: width,
      height: height,
      maximized: maximized ?? false,
    );
  }

  /// Persists the full state, including the non-maximized size.
  Future<void> save(WindowState state) async {
    if (state.hasSize) {
      await _prefs.setDouble(widthKey, state.width!);
      await _prefs.setDouble(heightKey, state.height!);
    }
    await _prefs.setBool(maximizedKey, state.maximized);
  }

  /// Persists only the maximized flag, leaving the stored size untouched.
  ///
  /// Used when the window is maximized at flush time: the current size is the
  /// maximized extent, so writing it would lose the size to restore to.
  Future<void> saveMaximized(bool maximized) async {
    await _prefs.setBool(maximizedKey, maximized);
  }

  static bool _isUsable(double? value) =>
      value != null && value.isFinite && value > 0;
}
