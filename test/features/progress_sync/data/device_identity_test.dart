import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/progress_sync/data/device_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('deviceId', () {
    test('is made once and kept across runs', () async {
      final first = await DeviceIdentity(
        await SharedPreferences.getInstance(),
      ).deviceId();
      final again = await DeviceIdentity(
        await SharedPreferences.getInstance(),
      ).deviceId();

      expect(first, again);
      expect(
        first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('differs between installs', () async {
      final first = await DeviceIdentity(
        await SharedPreferences.getInstance(),
      ).deviceId();
      SharedPreferences.setMockInitialValues({});
      final other = await DeviceIdentity(
        await SharedPreferences.getInstance(),
      ).deviceId();

      expect(first, isNot(other));
    });
  });

  group('buildDeviceName', () {
    test('names the platform and the host', () {
      expect(
        buildDeviceName(platformLabel: 'Windows', hostName: 'DESKTOP-ABC'),
        'Windows (DESKTOP-ABC)',
      );
    });

    test('falls back to the platform alone without a host name', () {
      expect(buildDeviceName(platformLabel: 'iPad', hostName: ''), 'iPad');
    });
  });

  group('platformLabelFor', () {
    test('labels the platforms the app runs on', () {
      expect(platformLabelFor('windows'), 'Windows');
      expect(platformLabelFor('macos'), 'macOS');
      expect(platformLabelFor('ios'), 'iPad');
      expect(platformLabelFor('linux'), 'Linux');
    });
  });
}
