import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:logging/logging.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/window_state/data/window_controller.dart';
import 'package:novel_viewer/features/window_state/data/window_state_recorder.dart';
import 'package:novel_viewer/features/window_state/data/window_state_repository.dart';
import 'package:novel_viewer/features/window_state/domain/window_size_resolver.dart';

final _log = Logger('window_state');

/// What the primary display reports: its visible area in logical pixels. Null
/// when the display cannot be read.
typedef DisplayInfo = ({Size? workArea});

/// Outcome of [initializeWindowState].
class WindowStateBootstrapResult {
  const WindowStateBootstrapResult({this.recorder, this.pendingMaximize});

  /// The listener that keeps the stored state up to date, or null when window
  /// state persistence is not active on this platform.
  final WindowStateRecorder? recorder;

  /// Completes once the deferred maximize has run (or given up); null when the
  /// window was not stored as maximized. Callers need not await it — it is
  /// exposed so tests can.
  final Future<void>? pendingMaximize;
}

/// Restores the saved window size and starts recording further changes.
///
/// Windows only: macOS zooms on launch (`MainFlutterWindow.swift`) and Linux is
/// out of scope, so on those platforms this is a no-op and nothing is written.
///
/// Sizing happens immediately, while the runner still has the window hidden, so
/// the user never sees it resize. Maximizing cannot: the runner calls
/// `ShowWindow(SW_SHOWNORMAL)` on Flutter's first frame, which would undo it —
/// so that is deferred until the window is actually visible.
///
/// Call after `SharedPreferences` is available and before `runApp`. The named
/// parameters exist so tests can drive this without a real window.
Future<WindowStateBootstrapResult> initializeWindowState({
  required SharedPreferences prefs,
  WindowController? window,
  Future<DisplayInfo> Function()? displayProvider,
  bool? isWindows,
  Duration pollInterval = const Duration(milliseconds: 50),
  int maxVisibilityPolls = 40,
}) async {
  if (!(isWindows ?? Platform.isWindows)) {
    return const WindowStateBootstrapResult();
  }

  final controller = window ?? const WindowManagerController();
  final repository = WindowStateRepository(prefs);

  // Restoring the window is a convenience; it must never keep the app from
  // starting, so a failing platform channel is logged and skipped.
  try {
    final saved = repository.load();
    final display = await (displayProvider ?? _primaryDisplay)();

    // Everything here is in logical pixels: the stored size, the work area
    // (`Display.visibleSize` is `rcWork / scaleFactor`) and what setSize wants.
    await controller.setSize(resolveWindowSize(saved, display.workArea));

    // The recorder flushes a pending write in onWindowClose, which only has
    // time to finish if the native close is intercepted.
    await controller.setPreventClose(true);

    final recorder =
        WindowStateRecorder(repository: repository, window: controller);
    controller.addListener(recorder);

    return WindowStateBootstrapResult(
      recorder: recorder,
      pendingMaximize: saved.maximized
          ? _maximizeOnceVisible(controller, pollInterval, maxVisibilityPolls)
          : null,
    );
  } catch (e, stack) {
    _log.warning('Could not restore the window state; continuing startup', e,
        stack);
    return const WindowStateBootstrapResult();
  }
}

/// Maximizes as soon as the runner has shown the window.
///
/// Gives up on timeout rather than maximizing a still-hidden window: that would
/// reveal a blank frame the runner deliberately kept hidden.
Future<void> _maximizeOnceVisible(
  WindowController controller,
  Duration interval,
  int maxPolls,
) async {
  try {
    for (var poll = 0; poll < maxPolls; poll++) {
      if (await controller.isVisible()) {
        await controller.maximize();
        return;
      }
      await Future<void>.delayed(interval);
    }
    _log.warning('Window never became visible; skipping restore of maximized '
        'state');
  } catch (e, stack) {
    _log.warning('Failed to restore the maximized window state', e, stack);
  }
}

/// Primary display metrics, or null if they can't be read (the clamp is then
/// skipped rather than blocking startup).
Future<DisplayInfo> _primaryDisplay() async {
  try {
    final display = await screenRetriever.getPrimaryDisplay();
    return (workArea: display.visibleSize ?? display.size);
  } catch (e, stack) {
    _log.warning('Could not read the primary display; skipping clamp', e,
        stack);
    return (workArea: null);
  }
}
