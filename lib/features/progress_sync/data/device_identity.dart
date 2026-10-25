import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:novel_viewer/shared/platform/ios_device_kind.dart';

/// Names this installation to the other devices (design D10).
class DeviceIdentity {
  static const _deviceIdKey = 'progress_sync_device_id';

  final SharedPreferences _prefs;

  DeviceIdentity(this._prefs);

  /// A UUID made the first time it is asked for and kept from then on, so the
  /// device keeps writing the same `device-<id>.json`.
  Future<String> deviceId() async {
    final existing = _prefs.getString(_deviceIdKey);
    if (existing != null) return existing;
    final created = const Uuid().v4();
    await _prefs.setString(_deviceIdKey, created);
    return created;
  }
}

/// The name another device shows when it asks whether to move to this
/// device's position.
String buildDeviceName({
  required String platformLabel,
  required String hostName,
}) {
  return hostName.isEmpty ? platformLabel : '$platformLabel ($hostName)';
}

/// A reader-facing label for a `Platform.operatingSystem` value.
///
/// iOS runs on both the iPhone and the iPad, and a reader who syncs both needs
/// to tell them apart in the prompt, so an iOS device is labelled by
/// [iosDeviceKind]. The kind is ignored on every other system.
String platformLabelFor(
  String operatingSystem, {
  required IosDeviceKind iosDeviceKind,
}) {
  return switch (operatingSystem) {
    'windows' => 'Windows',
    'macos' => 'macOS',
    'ios' => switch (iosDeviceKind) {
      IosDeviceKind.phone => 'iPhone',
      IosDeviceKind.pad => 'iPad',
      IosDeviceKind.unknown => 'iOS',
    },
    'linux' => 'Linux',
    _ => operatingSystem,
  };
}
