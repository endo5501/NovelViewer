import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/window_state/data/window_state_recorder.dart';
import 'package:novel_viewer/features/window_state/domain/window_state.dart';

import '../../../test_utils/fake_window_controller.dart';
import '../../../test_utils/recording_window_state_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingWindowStateRepository repository;
  late FakeWindowController window;

  Future<void> setUpWith([Map<String, Object> stored = const {}]) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    repository = RecordingWindowStateRepository(prefs);
    window = FakeWindowController();
  }

  WindowStateRecorder buildRecorder() =>
      WindowStateRecorder(repository: repository, window: window);

  /// Runs [body] inside fake time, draining microtasks afterwards so the
  /// recorder's async flush completes before assertions run.
  void withFakeTime(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      body(async);
      async.flushMicrotasks();
    });
  }

  group('WindowStateRecorder - debounce', () {
    test('saves once, 500ms after the resize stops', () async {
      await setUpWith();
      final recorder = buildRecorder();
      window.size = const Size(1600, 1000);

      withFakeTime((async) {
        recorder.onWindowResized();

        async.elapse(const Duration(milliseconds: 499));
        async.flushMicrotasks();
        expect(repository.saveCount, 0,
            reason: 'must not save before the delay elapses');

        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
      });

      expect(repository.saveCount, 1);
      expect(repository.load(), const WindowState(width: 1600, height: 1000));
    });

    test('collapses a burst of events into a single save', () async {
      await setUpWith();
      final recorder = buildRecorder();

      withFakeTime((async) {
        for (var i = 0; i < 10; i++) {
          window.size = Size(1000 + i * 50, 800);
          recorder.onWindowResized();
          async.elapse(const Duration(milliseconds: 100));
        }
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
      });

      expect(repository.saveCount, 1,
          reason: 'intermediate sizes must not be persisted');
      expect(repository.load(), const WindowState(width: 1450, height: 800));
    });

    test('onWindowResize also arms the debounce', () async {
      await setUpWith();
      final recorder = buildRecorder();
      window.size = const Size(1500, 950);

      withFakeTime((async) {
        recorder.onWindowResize();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
      });

      expect(repository.load(), const WindowState(width: 1500, height: 950));
    });
  });

  group('WindowStateRecorder - maximized handling', () {
    test('keeps the stored size when maximized at flush time', () async {
      await setUpWith({'window_width': 1400.0, 'window_height': 900.0});
      final recorder = buildRecorder();
      // The OS reports the maximized extent, which must not overwrite the size
      // the user restores to.
      window.size = const Size(1920, 1040);
      window.maximized = true;

      withFakeTime((async) {
        recorder.onWindowMaximize();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
      });

      expect(
        repository.load(),
        const WindowState(width: 1400, height: 900, maximized: true),
      );
    });

    test('persists the size and clears the flag when not maximized', () async {
      await setUpWith({
        'window_width': 1400.0,
        'window_height': 900.0,
        'window_maximized': true,
      });
      final recorder = buildRecorder();
      window.size = const Size(1500, 950);
      window.maximized = false;

      withFakeTime((async) {
        recorder.onWindowUnmaximize();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
      });

      expect(
        repository.load(),
        const WindowState(width: 1500, height: 950, maximized: false),
      );
    });

    test('result is identical whether resize or maximize fires first',
        () async {
      Future<WindowState> run({required bool resizeFirst}) async {
        await setUpWith({'window_width': 1400.0, 'window_height': 900.0});
        final recorder = buildRecorder();
        window.size = const Size(1920, 1040);
        window.maximized = true;

        withFakeTime((async) {
          if (resizeFirst) {
            recorder.onWindowResized();
            recorder.onWindowMaximize();
          } else {
            recorder.onWindowMaximize();
            recorder.onWindowResized();
          }
          async.elapse(const Duration(milliseconds: 500));
          async.flushMicrotasks();
        });
        return repository.load();
      }

      final resizeFirst = await run(resizeFirst: true);
      final maximizeFirst = await run(resizeFirst: false);
      expect(resizeFirst, maximizeFirst);
      expect(
        resizeFirst,
        const WindowState(width: 1400, height: 900, maximized: true),
      );
    });

    test('ignores a degenerate size reported by the OS', () async {
      await setUpWith({'window_width': 1400.0, 'window_height': 900.0});
      final recorder = buildRecorder();
      // e.g. a minimized window; storing this would destroy the real size.
      window.size = Size.zero;

      withFakeTime((async) {
        recorder.onWindowResized();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
      });

      expect(repository.load(), const WindowState(width: 1400, height: 900));
    });
  });

  group('WindowStateRecorder - close', () {
    test('flushes a pending change before destroying the window', () async {
      await setUpWith();
      final recorder = buildRecorder();
      window.size = const Size(1600, 1000);

      withFakeTime((async) {
        recorder.onWindowResized();
        async.elapse(const Duration(milliseconds: 100));
        // Quit before the debounce would have fired.
        recorder.onWindowClose();
        async.flushMicrotasks();
      });

      expect(repository.load(), const WindowState(width: 1600, height: 1000));
      expect(window.destroyCount, 1);
    });

    test('does not save again when nothing is pending', () async {
      await setUpWith();
      final recorder = buildRecorder();
      window.size = const Size(1600, 1000);

      withFakeTime((async) {
        recorder.onWindowResized();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        recorder.onWindowClose();
        async.flushMicrotasks();
      });

      expect(repository.saveCount, 1);
      expect(window.destroyCount, 1);
    });

    test('still destroys the window when the flush throws', () async {
      await setUpWith();
      final recorder = buildRecorder();
      window.size = const Size(1600, 1000);
      window.throwOnGetSize = true;

      withFakeTime((async) {
        recorder.onWindowResized();
        async.elapse(const Duration(milliseconds: 100));
        recorder.onWindowClose();
        async.flushMicrotasks();
      });

      expect(window.destroyCount, 1, reason: 'the app must stay closable');
    });

    test('a failing debounced flush does not crash the app', () async {
      await setUpWith();
      final recorder = buildRecorder();
      window.throwOnGetSize = true;

      withFakeTime((async) {
        recorder.onWindowResized();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
      });

      expect(repository.saveCount, 0);
    });

    test('dispose cancels a pending debounce', () async {
      await setUpWith();
      final recorder = buildRecorder();
      window.size = const Size(1600, 1000);

      withFakeTime((async) {
        recorder.onWindowResized();
        recorder.dispose();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
      });

      expect(repository.saveCount, 0);
      expect(repository.load(), WindowState.empty);
    });
  });
}
