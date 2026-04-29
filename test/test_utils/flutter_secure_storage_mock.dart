import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mocks the `flutter_secure_storage` plugin's `MethodChannel` for use in
/// widget/unit tests. Returns a [Map] that the test can read from / mutate
/// directly to inspect or seed storage state.
///
/// `forceWriteFailure: true` makes every `write` call throw a
/// [PlatformException], simulating a backend failure (e.g. libsecret missing
/// on Linux). Reads continue to work against the underlying map.
class FlutterSecureStorageMock {
  static const _channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  final Map<String, String> store;
  bool forceWriteFailure;

  FlutterSecureStorageMock({
    Map<String, String>? initial,
    this.forceWriteFailure = false,
  }) : store = Map<String, String>.from(initial ?? const {});

  /// Install the handler on the binding's binary messenger. Call inside
  /// `setUp()` after `TestWidgetsFlutterBinding.ensureInitialized()`.
  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, _handle);
  }

  /// Remove the handler. Call inside `tearDown()`.
  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }

  Future<Object?> _handle(MethodCall call) async {
    final args = (call.arguments as Map?) ?? const {};
    final key = args['key'] as String?;
    switch (call.method) {
      case 'read':
        return store[key];
      case 'readAll':
        return Map<String, String>.from(store);
      case 'write':
        if (forceWriteFailure) {
          throw PlatformException(
            code: 'write_failed',
            message: 'simulated secure storage failure',
          );
        }
        store[key!] = args['value'] as String;
        return null;
      case 'delete':
        store.remove(key);
        return null;
      case 'deleteAll':
        store.clear();
        return null;
      case 'containsKey':
        return store.containsKey(key);
      default:
        return null;
    }
  }
}
