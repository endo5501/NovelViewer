// Checks that the host answers which kind of iOS device this is, and that the
// answer matches what the run expects.
//
// The Dart side of the channel is unit-tested against a mock; only a real run
// shows that AppDelegate.swift registers the channel and answers it. Run once
// on an iPhone and once on an iPad, each with the kind that device should
// report:
//   fvm flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/ios_device_kind_test.dart \
//     --dart-define=EXPECTED_IOS_DEVICE_KIND=phone -d <iPhone simulator>
//   fvm flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/ios_device_kind_test.dart \
//     --dart-define=EXPECTED_IOS_DEVICE_KIND=pad -d <iPad simulator>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:novel_viewer/features/progress_sync/data/device_identity.dart';
import 'package:novel_viewer/shared/platform/ios_device_kind.dart';

const _expected = String.fromEnvironment('EXPECTED_IOS_DEVICE_KIND');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('the host reports the kind of device it is', () async {
    expect(
      _expected,
      isIn(const ['phone', 'pad']),
      reason: 'pass --dart-define=EXPECTED_IOS_DEVICE_KIND=phone or pad',
    );

    final kind = await readIosDeviceKind();

    expect(kind, iosDeviceKindFromIdiom(_expected));
    // ignore: avoid_print
    print(
      'iOS device kind: ${kind.name}, labelled '
      '${platformLabelFor('ios', iosDeviceKind: kind)}',
    );
  });
}
