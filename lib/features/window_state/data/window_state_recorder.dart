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
  bool _closing = false;

  /// Completes when the write in flight finishes. Serializes writes: without
  /// it a slow flush could land after a newer one and put stale state on disk.
  /// Created lazily so it always belongs to the caller's zone.
  Future<void>? _writeInFlight;

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
    // Releasing the interception makes the window emit close a second time;
    // only the first pass does any work.
    if (_closing) return;
    _closing = true;
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

  /// Writes the current state, then closes the window.
  ///
  /// Flushes unconditionally rather than only when the debounce is armed: the
  /// Windows plugin only emits resize events for interactive drags, so a size
  /// set by Aero Snap or another program would otherwise never be stored. This
  /// makes "what you quit with is what you get" hold in every case.
  ///
  /// `setPreventClose(true)` is what buys the time: the native side reports the
  /// close and waits, so the write can finish before the process goes away.
  /// [WindowController.destroy] therefore has to run whatever the flush did, or
  /// the app would become unclosable.
  Future<void> _closeAfterFlush() async {
    try {
      _timer?.cancel();
      _timer = null;
      await _flushSafely();
    } finally {
      // Release the interception, then let the close run its normal course.
      //
      // close() re-posts WM_CLOSE, which now reaches DefWindowProc and takes
      // the runner's DestroyWindow path. destroy() only posts WM_QUIT, leaving
      // the window undestroyed — measured at ~5.9s to exit versus ~0.17s for
      // the normal path, which the user sees as the app hanging on Alt+F4.
      // destroy() stays as the fallback so the app is always closable.
      await _ignoringErrors(() => _window.setPreventClose(false),
          'release the close interception');
      try {
        await _window.close();
      } catch (e, stack) {
        _log.warning('Failed to close the window; forcing quit', e, stack);
        await _ignoringErrors(() => _window.destroy(), 'force quit');
      }
    }
  }

  /// Queues a flush behind any that is already running and swallows failures.
  ///
  /// Losing the window size is never worth surfacing to the user, let alone
  /// taking down a close in progress.
  Future<void> _flushSafely() async {
    final previous = _writeInFlight;
    final mine = Completer<void>();
    _writeInFlight = mine.future;
    try {
      if (previous != null) await previous;
      await _flush();
    } catch (e, stack) {
      _log.warning('Failed to persist window state', e, stack);
    } finally {
      mine.complete();
      if (identical(_writeInFlight, mine.future)) _writeInFlight = null;
    }
  }

  Future<void> _ignoringErrors(
    Future<void> Function() action,
    String description,
  ) async {
    try {
      await action();
    } catch (e, stack) {
      _log.warning('Failed to $description', e, stack);
    }
  }

  Future<void> _flush() async {
    // A minimized window reports SW_SHOWMINIMIZED (so isMaximized() is false
    // even when it was maximized) and an off-screen placeholder rect. Writing
    // either would replace the user's geometry with junk — closing from the
    // taskbar while minimized is an ordinary thing to do.
    if (await _window.isMinimized()) {
      _log.fine('Window is minimized; keeping the stored state');
      return;
    }

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
