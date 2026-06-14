import 'dart:io';

import 'package:logging/logging.dart';
import 'package:win32_registry/win32_registry.dart';

final _log = Logger('app_update.registry');

/// Reads string values from the Windows registry. Abstracted so the
/// distribution detector can be unit-tested without touching a real registry.
abstract class RegistryReader {
  /// Returns the string value at [keyPath]\[valueName] under HKCU, or null if
  /// the key/value is missing or cannot be read.
  String? readString(String keyPath, String valueName);
}

class Win32RegistryReader implements RegistryReader {
  const Win32RegistryReader();

  @override
  String? readString(String keyPath, String valueName) {
    if (!Platform.isWindows) return null;
    RegistryKey? key;
    try {
      key = Registry.openPath(RegistryHive.currentUser, path: keyPath);
      return key.getStringValue(valueName);
    } catch (e, stack) {
      // A missing key is the normal case for most users, so log at FINE to
      // avoid polluting release logs while still keeping the failure traceable.
      _log.fine('Registry read failed for $keyPath\\$valueName: $e', e, stack);
      return null;
    } finally {
      key?.close();
    }
  }
}
