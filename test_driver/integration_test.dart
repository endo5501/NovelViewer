// Host-side driver for integration tests run with `flutter drive`.
//
// Physical iOS devices need `flutter drive --profile`: `flutter test` always
// launches a JIT debug build, which iPadOS 26 refuses to execute without a
// debugger attached (EXC_BAD_ACCESS, KERN_CODESIGN_ERROR at startup).
// On a device, `flutter drive` also leaves the app installed, so the downloaded
// model is reused on the next run. The simulator keeps no app data between
// runs either way, so there the model is downloaded each time.
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
