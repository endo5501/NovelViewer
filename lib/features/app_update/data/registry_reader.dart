import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

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
    } catch (_) {
      return null;
    } finally {
      key?.close();
    }
  }
}
