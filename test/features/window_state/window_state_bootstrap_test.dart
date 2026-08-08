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
      displayProvider: () async => (workArea: workArea),
      isWindows: isWindows,
      // Keep the visibility poll instantaneous in tests.
      pollInterval: Duration.zero,
      maxVisibilityPolls: 10,
    );
  }

  group('initializeWindowState - restore', () {
    test('sizes the window to the stored size', () async {
      await setUpWith({'window_width': 1600.0, 'window_height': 1000.0});
      await run();
      expect(window.sizeSetByCaller, const Size(1600, 1000));
    });

    test('uses the default size on a first launch', () async {
      await setUpWith();
      await run();
      expect(window.sizeSetByCaller, const Size(1280, 720));
      expect(window.maximizeCount, 0);
    });

    test('clamps a stored size larger than the work area', () async {
      await setUpWith({'window_width': 3400.0, 'window_height': 1900.0});
      await run();
      expect(window.sizeSetByCaller, const Size(1920, 1040));
    });

    test('still sizes the window when the display cannot be read', () async {
      await setUpWith({'window_width': 1600.0, 'window_height': 1000.0});
      await run(workArea: null);
      expect(window.sizeSetByCaller, const Size(1600, 1000));
    });

    test('never shows the window itself', () async {
      await setUpWith({'window_width': 1600.0, 'window_height': 1000.0});
      await run();
      // The runner shows the window on Flutter's first frame; revealing it any
      // earlier would put a blank window on screen during startup.
      expect(window.calls, isNot(contains('show')));
    });
  });

  group('initializeWindowState - maximized restore', () {
    test('maximizes only after the runner has shown the window', () async {
      await setUpWith({
        'window_width': 1400.0,
        'window_height': 900.0,
        'window_maximized': true,
      });
      window.visibleAfterPolls = 3;
      final result = await run();
      expect(window.maximizeCount, 0, reason: 'window is not visible yet');

      await result.pendingMaximize;

      // Sizing first leaves the normal size as the OS restore target.
      expect(window.calls, ['setSize', 'setPreventClose(true)', 'maximize']);
      expect(window.sizeSetByCaller, const Size(1400, 900));
    });

    test('gives up rather than forcing a window that never appears', () async {
      await setUpWith({
        'window_width': 1400.0,
        'window_height': 900.0,
        'window_maximized': true,
      });
      window.visibleAfterPolls = 1000;
      final result = await run();
      await result.pendingMaximize;
      expect(window.maximizeCount, 0);
    });

    test('does not maximize when the flag is false', () async {
      await setUpWith({
        'window_width': 1400.0,
        'window_height': 900.0,
        'window_maximized': false,
      });
      final result = await run();
      expect(result.pendingMaximize, isNull);
      expect(window.maximizeCount, 0);
    });
  });

  group('initializeWindowState - failure handling', () {
    test('a failing window call never blocks startup', () async {
      await setUpWith({'window_width': 1600.0, 'window_height': 1000.0});
      window.throwOnSetSize = true;
      final result = await run();
      expect(result.recorder, isNull);
      expect(result.pendingMaximize, isNull);
      // No listener left behind on a half-finished setup.
      expect(window.listeners, isEmpty);
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
      expect(result.pendingMaximize, isNull);
      expect(window.calls, isEmpty);
      expect(window.listeners, isEmpty);
      expect(window.preventClose, isNull);
    });
  });
}
