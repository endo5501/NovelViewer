import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/platform/ios_device_kind.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('iosDeviceKindFromIdiom', () {
    test('maps the phone idiom to a phone', () {
      expect(iosDeviceKindFromIdiom('phone'), IosDeviceKind.phone);
    });

    test('maps the pad idiom to a pad', () {
      expect(iosDeviceKindFromIdiom('pad'), IosDeviceKind.pad);
    });

    test('maps any other answer to unknown', () {
      for (final idiom in const [null, '', 'mac', 'tv', 'Phone', 42]) {
        expect(
          iosDeviceKindFromIdiom(idiom),
          IosDeviceKind.unknown,
          reason: 'idiom $idiom',
        );
      }
    });
  });

  group('readIosDeviceKind', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    void answer(Future<Object?> Function(MethodCall call) handler) {
      messenger.setMockMethodCallHandler(iosDeviceKindChannel, handler);
    }

    tearDown(() {
      messenger.setMockMethodCallHandler(iosDeviceKindChannel, null);
    });

    test('asks the host for its idiom', () async {
      final calls = <String>[];
      answer((call) async {
        calls.add(call.method);
        return 'phone';
      });

      expect(await readIosDeviceKind(), IosDeviceKind.phone);
      expect(calls, ['idiom']);
    });

    test('reports a pad the host names', () async {
      answer((call) async => 'pad');

      expect(await readIosDeviceKind(), IosDeviceKind.pad);
    });

    test('reports unknown when the host fails', () async {
      answer((call) async => throw PlatformException(code: 'boom'));

      expect(await readIosDeviceKind(), IosDeviceKind.unknown);
    });

    test('reports unknown when nothing answers the channel', () async {
      // No handler: the call ends in a MissingPluginException.
      expect(await readIosDeviceKind(), IosDeviceKind.unknown);
    });
  });
}
