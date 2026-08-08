import 'dart:async';

import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';
import 'package:novel_viewer/features/window_state/data/window_controller.dart';
import 'package:novel_viewer/features/window_state/data/window_state_repository.dart';
import 'package:novel_viewer/features/window_state/domain/window_state.dart';

final _log = Logger('window_state');

/// Persists the window geometry as the user changes it.
///
/// Resize and maximize events only arm a timer; the actual state is read back
/// from the window when the timer fires. That makes the result independent of
/// the order in which `onWindowResized` and `onWindowMaximize` arrive, which is
/// platform-dependent.
class WindowStateRecorder with WindowListener {
  static const debounceDelay = Duration(milliseconds: 500);

  final WindowStateRepository _repository;
  final WindowController _window;

  Timer? _timer;
  bool _disposed = false;

  WindowStateRecorder({
    required WindowStateRepository repository,
    required WindowController window,
  })  : _repository = repository,
        _window = window;

  @override
  void onWindowResize() => _schedule();

  @override
  void onWindowResized() => _schedule();

  @override
  void onWindowMaximize() => _schedule();

  @override
  void onWindowUnmaximize() => _schedule();

  @override
  void onWindowClose() {
    unawaited(_closeAfterFlush());
  }

  /// Cancels any pending write. The window is left alone.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounceDelay, () {
      _timer = null;
      unawaited(_flushSafely());
    });
  }

  /// Flushes any pending write, then closes the window.
  ///
  /// `setPreventClose(true)` is what makes this possible: the native side
  /// reports the close and waits, so the write can finish before the process
  /// goes away. [WindowController.destroy] therefore has to run no matter what
  /// the flush did, or the app would become unclosable.
  Future<void> _closeAfterFlush() async {
    try {
      if (_timer != null) {
        _timer!.cancel();
        _timer = null;
        await _flushSafely();
      }
    } finally {
      await _window.destroy();
    }
  }

  Future<void> _flushSafely() async {
    try {
      await _flush();
    } catch (e, stack) {
      // Losing the window size is never worth surfacing to the user, let alone
      // taking down a close in progress.
      _log.warning('Failed to persist window state', e, stack);
    }
  }

  Future<void> _flush() async {
    final maximized = await _window.isMaximized();
    if (maximized) {
      // getSize() would report the maximized extent; keep the stored size so
      // "restore down" still returns to the user's own size.
      await _repository.saveMaximized(true);
      return;
    }

    final size = await _window.getSize();
    if (!_isUsable(size.width) || !_isUsable(size.height)) {
      // A minimized or otherwise degenerate window; the flag is still accurate.
      _log.fine('Ignoring degenerate window size $size');
      await _repository.saveMaximized(false);
      return;
    }

    await _repository.save(
      WindowState(width: size.width, height: size.height, maximized: false),
    );
  }

  static bool _isUsable(double value) => value.isFinite && value > 0;
}
