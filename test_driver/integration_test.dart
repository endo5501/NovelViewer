// Host-side driver for integration tests run with `flutter drive`.
//
// Physical iOS devices need `flutter drive --profile`: `flutter test` always
// launches a JIT debug build, which iPadOS 26 refuses to execute without a
// debugger attached (EXC_BAD_ACCESS, KERN_CODESIGN_ERROR at startup).
// On a device, every `flutter drive` run ends with the app uninstalled, and the
// app's data with it: the downloaded model, and the reader's novels and
// settings. Measured on iPadOS 26.6.2 (2026-10-24): each run got a new data
// container and the app was gone afterwards. Back up the app's Documents and
// Library before a device run (docs/ipad.md). The simulator keeps no app data
// between runs either, so the model is downloaded each time there too.
//
// The test's reportData lands in build/integration_response_data.json on the
// host, including when the test fails, so a partial measurement is not lost.

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  // A first run downloads the Piper model and dictionary before measuring,
  // which can outlast the 20-minute default on a slow connection.
  timeout: const Duration(minutes: 30),
  writeResponseOnFailure: true,
);
