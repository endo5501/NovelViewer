import 'dart:io';

import 'package:logging/logging.dart';
import 'package:novel_viewer/features/app_update/data/registry_reader.dart';
import 'package:novel_viewer/features/app_update/domain/distribution_type.dart';

final _log = Logger('app_update.distribution');

/// Determines whether the running app is an installed copy (eligible for the
/// in-app auto-update flow) or a portable ZIP extraction.
///
/// The installer writes `HKCU\Software\NovelViewer\InstallType = "installer"`.
/// Any other state — missing key, unreadable, non-Windows — is treated as
/// portable, which is the safe default (no silent installer execution).
class DistributionDetector {
  DistributionDetector({
    RegistryReader registryReader = const Win32RegistryReader(),
    bool? isWindows,
  })  : _registryReader = registryReader,
        _isWindows = isWindows ?? Platform.isWindows;

  static const registryKeyPath = r'Software\NovelViewer';
  static const registryValueName = 'InstallType';
  static const installerValue = 'installer';

  final RegistryReader _registryReader;
  final bool _isWindows;

  DistributionType detect() {
    if (!_isWindows) return DistributionType.portable;
    String? value;
    try {
      value = _registryReader.readString(registryKeyPath, registryValueName);
    } catch (e, stack) {
      // Expected fallback (portable installs hit this on every launch), so log
      // at FINE to keep release logs clean.
      _log.fine('Registry read failed; defaulting to portable: $e', e, stack);
      return DistributionType.portable;
    }
    return value == installerValue
        ? DistributionType.installer
        : DistributionType.portable;
  }
}
