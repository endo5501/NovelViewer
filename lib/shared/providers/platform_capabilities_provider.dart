import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';

/// The capability set of the running platform.
///
/// This is the only place the application reads `dart:io`'s `Platform` to
/// decide whether a feature may be offered. Consumers watch the per-feature
/// boolean provider that belongs to their feature instead of this one, so a
/// widget test can override a single feature without knowing the model:
/// `Platform` cannot be overridden from a test, but a provider can.
final platformCapabilitiesProvider = Provider<PlatformCapabilities>(
  (ref) => PlatformCapabilities.forPlatform(
    isIOS: Platform.isIOS,
    isMacOS: Platform.isMacOS,
  ),
);
