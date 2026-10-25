import 'package:flutter/services.dart';

/// Which kind of iOS device the app is running on.
///
/// `dart:io`'s `Platform` reports `ios` for an iPhone and an iPad alike, so
/// the kind is asked of the host instead (see `AppDelegate.swift`). It is
/// [unknown] where the host could not say, which a reader-facing label shows
/// as plain "iOS" rather than guessing one of the two.
enum IosDeviceKind { phone, pad, unknown }

/// The channel `AppDelegate.swift` answers on.
const iosDeviceKindChannel = MethodChannel('novel_viewer/device_kind');

/// Maps the host's answer to a kind. Anything but the two idioms the app is
/// built for is [IosDeviceKind.unknown].
IosDeviceKind iosDeviceKindFromIdiom(Object? idiom) {
  return switch (idiom) {
    'phone' => IosDeviceKind.phone,
    'pad' => IosDeviceKind.pad,
    _ => IosDeviceKind.unknown,
  };
}

/// Asks the host which kind of device this is. Never throws: a failed call is
/// [IosDeviceKind.unknown], because the kind only names the device to the
/// reader's other devices and is no reason to stop the app from starting.
Future<IosDeviceKind> readIosDeviceKind() async {
  try {
    return iosDeviceKindFromIdiom(
      await iosDeviceKindChannel.invokeMethod<Object?>('idiom'),
    );
  } on PlatformException {
    return IosDeviceKind.unknown;
  } on MissingPluginException {
    return IosDeviceKind.unknown;
  }
}
