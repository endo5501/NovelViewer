import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/window_state/window_state_bootstrap.dart';

import '../../test_utils/fake_window_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FakeWindowController window;

  Future<void> setUpWith([Map<String, Object> stored = const {}]) async {
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    window = FakeWindowController();
  }

  Future<WindowStateBootstrapResult> run({
    Size? workArea = const Size(1920, 1040),
    bool isWindows = true,
  }) {
    return initializeWindowState(
      prefs: prefs,
      window: window,
      workAreaProvider: () async => workArea,
      isWindows: isWindows,
    );
  }

  group('initializeWindowState - restore', () {
    test('opens at the stored size', () async {
      await setUpWith({'window_width': 1600.0, 'window_height': 1000.0});
      await run();
      expect(window.readyOptions?.size, const Size(1600, 1000));
      expect(window.calls, ['waitUntilReadyToShow', 'show']);
    });

    test('opens at the default size on a first launch', () async {
      await setUpWith();
      await run();
      expect(window.readyOptions?.size, const Size(1280, 720));
      expect(window.maximizeCount, 0);
    });

    test('clamps a stored size larger than the work area', () async {
      await setUpWith({'window_width': 3400.0, 'window_height': 1900.0});
      await run();
      expect(window.readyOptions?.size, const Size(1920, 1040));
    });

    test('still opens when the work area cannot be determined', () async {
      await setUpWith({'window_width': 1600.0, 'window_height': 1000.0});
      await run(workArea: null);
      expect(window.readyOptions?.size, const Size(1600, 1000));
      expect(window.showCount, 1);
    });
  });

  group('initializeWindowState - maximized restore', () {
    test('sizes the window before maximizing so restore-down is correct',
        () async {
      await setUpWith({
        'window_width': 1400.0,
        'window_height': 900.0,
        'window_maximized': true,
      });
      await run();
      // The normal size must reach the OS first; maximizing afterwards leaves
      // it as the restore target.
      expect(window.readyOptions?.size, const Size(1400, 900));
      expect(window.calls, ['waitUntilReadyToShow', 'maximize', 'show']);
    });

    test('does not maximize when the flag is false', () async {
      await setUpWith({
        'window_width': 1400.0,
        'window_height': 900.0,
        'window_maximized': false,
      });
      await run();
      expect(window.maximizeCount, 0);
      expect(window.calls, ['waitUntilReadyToShow', 'show']);
    });
  });

  group('initializeWindowState - wiring', () {
    test('registers a recorder and intercepts close', () async {
      await setUpWith();
      final result = await run();
      expect(result.recorder, isNotNull);
      expect(window.listeners, contains(result.recorder));
      // Needed so a pending write can finish before the process exits.
      expect(window.preventClose, isTrue);
    });
  });

  group('initializeWindowState - other platforms', () {
    test('does nothing on macOS and Linux', () async {
      await setUpWith({'window_width': 1600.0, 'window_height': 1000.0});
      final result = await run(isWindows: false);
      expect(result.recorder, isNull);
      expect(window.calls, isEmpty);
      expect(window.listeners, isEmpty);
      expect(window.preventClose, isNull);
    });
  });
}
