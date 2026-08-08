import 'dart:io';
import 'dart:ui';

import 'package:logging/logging.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:novel_viewer/features/window_state/data/window_controller.dart';
import 'package:novel_viewer/features/window_state/data/window_state_recorder.dart';
import 'package:novel_viewer/features/window_state/data/window_state_repository.dart';
import 'package:novel_viewer/features/window_state/domain/window_size_resolver.dart';

final _log = Logger('window_state');

/// Outcome of [initializeWindowState].
class WindowStateBootstrapResult {
  const WindowStateBootstrapResult({this.recorder});

  /// The listener that keeps the stored state up to date, or null when window
  /// state persistence is not active on this platform.
  final WindowStateRecorder? recorder;
}

/// Restores the saved window size and starts recording further changes.
///
/// Windows only: macOS zooms on launch (`MainFlutterWindow.swift`) and Linux is
/// out of scope, so on those platforms this is a no-op and nothing is written.
///
/// Call after `SharedPreferences` is available and before `runApp`. The named
/// [window], [workAreaProvider] and [isWindows] parameters exist so tests can
/// drive this without a real window.
Future<WindowStateBootstrapResult> initializeWindowState({
  required SharedPreferences prefs,
  WindowController? window,
  Future<Size?> Function()? workAreaProvider,
  bool? isWindows,
}) async {
  if (!(isWindows ?? Platform.isWindows)) {
    return const WindowStateBootstrapResult();
  }

  final controller = window ?? const WindowManagerController();
  final repository = WindowStateRepository(prefs);
  final saved = repository.load();
  final workArea = await (workAreaProvider ?? _primaryWorkArea)();
  final size = resolveWindowSize(saved, workArea);

  await controller.waitUntilReadyToShow(
    WindowOptions(size: size),
    () async {
      // Size first, then maximize: the size the OS keeps as the restore target
      // is whatever it had before maximizing.
      if (saved.maximized) {
        await controller.maximize();
      }
      await controller.show();
    },
  );

  // The recorder flushes a pending write in onWindowClose, which only has time
  // to finish if the native close is intercepted.
  await controller.setPreventClose(true);

  final recorder =
      WindowStateRecorder(repository: repository, window: controller);
  controller.addListener(recorder);

  return WindowStateBootstrapResult(recorder: recorder);
}

/// Visible size of the primary display in logical pixels, or null if it can't
/// be read (the clamp is then skipped rather than blocking startup).
Future<Size?> _primaryWorkArea() async {
  try {
    final display = await screenRetriever.getPrimaryDisplay();
    return display.visibleSize ?? display.size;
  } catch (e, stack) {
    _log.warning('Could not read the primary display; skipping clamp', e,
        stack);
    return null;
  }
}
