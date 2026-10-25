import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_providers.dart';
import 'package:novel_viewer/shared/platform/ios_device_kind.dart';
import 'package:novel_viewer/shared/providers/device_platform_providers.dart';

void main() {
  String deviceNameOn(String operatingSystem, IosDeviceKind kind) {
    final container = ProviderContainer(
      overrides: [
        operatingSystemProvider.overrideWithValue(operatingSystem),
        iosDeviceKindProvider.overrideWithValue(kind),
      ],
    );
    addTearDown(container.dispose);
    return container.read(progressSyncDeviceNameProvider);
  }

  test('an iPhone names itself an iPhone', () {
    expect(deviceNameOn('ios', IosDeviceKind.phone), startsWith('iPhone'));
  });

  test('an iPad names itself an iPad', () {
    expect(deviceNameOn('ios', IosDeviceKind.pad), startsWith('iPad'));
  });

  test('an iOS device of unknown kind names itself iOS', () {
    expect(deviceNameOn('ios', IosDeviceKind.unknown), startsWith('iOS'));
  });

  test('a desktop keeps its platform name', () {
    expect(
      deviceNameOn('windows', IosDeviceKind.unknown),
      startsWith('Windows'),
    );
  });

  test('the device kind is unknown until the app is told it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(iosDeviceKindProvider), IosDeviceKind.unknown);
  });
}
