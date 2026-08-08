import 'dart:ui';

import 'package:window_manager/window_manager.dart';

/// Thin seam over the parts of `window_manager` this feature uses.
///
/// Keeps the debounce/maximize logic in [WindowStateRecorder] testable: unit
/// tests inject a fake instead of driving a real window through a method
/// channel.
abstract class WindowController {
  Future<Size> getSize();

  Future<bool> isMaximized();

  /// Whether the runner has shown the window yet. Maximizing before that point
  /// is undone by the runner's `ShowWindow(SW_SHOWNORMAL)`.
  Future<bool> isVisible();

  /// A minimized window reports a placeholder rect, not the user's size.
  Future<bool> isMinimized();

  /// Asks the window to close, which with the interception released takes the
  /// runner's normal `DestroyWindow` path.
  Future<void> close();

  Future<void> setSize(Size size);

  Future<void> maximize();

  Future<void> destroy();

  Future<void> setPreventClose(bool preventClose);

  void addListener(WindowListener listener);

  void removeListener(WindowListener listener);
}

/// [WindowController] backed by the real `window_manager` singleton.
class WindowManagerController implements WindowController {
  const WindowManagerController();

  @override
  Future<Size> getSize() => windowManager.getSize();

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<bool> isVisible() => windowManager.isVisible();

  @override
  Future<bool> isMinimized() => windowManager.isMinimized();

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> setSize(Size size) => windowManager.setSize(size);

  @override
  Future<void> maximize() => windowManager.maximize();

  @override
  Future<void> destroy() => windowManager.destroy();

  @override
  Future<void> setPreventClose(bool preventClose) =>
      windowManager.setPreventClose(preventClose);

  @override
  void addListener(WindowListener listener) =>
      windowManager.addListener(listener);

  @override
  void removeListener(WindowListener listener) =>
      windowManager.removeListener(listener);
}
