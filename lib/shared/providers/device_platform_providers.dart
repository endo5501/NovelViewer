import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/shared/platform/ios_device_kind.dart';

/// The running system's `Platform.operatingSystem`, behind a provider so a
/// test can name a system it is not running on.
final operatingSystemProvider = Provider<String>(
  (ref) => Platform.operatingSystem,
);

/// Which kind of iOS device this is, read once at startup and overridden in
/// `main.dart`. It stays [IosDeviceKind.unknown] on every other system, and
/// wherever the app was not told.
final iosDeviceKindProvider = Provider<IosDeviceKind>(
  (ref) => IosDeviceKind.unknown,
);
