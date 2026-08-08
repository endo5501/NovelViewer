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

  Future<void> setSize(Size size);

  Future<void> maximize();

  Future<void> show();

  Future<void> destroy();

  Future<void> setPreventClose(bool preventClose);

  Future<void> waitUntilReadyToShow(
    WindowOptions options,
    Future<void> Function() onReady,
  );

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
  Future<void> setSize(Size size) => windowManager.setSize(size);

  @override
  Future<void> maximize() => windowManager.maximize();

  @override
  Future<void> show() => windowManager.show();

  @override
  Future<void> destroy() => windowManager.destroy();

  @override
  Future<void> setPreventClose(bool preventClose) =>
      windowManager.setPreventClose(preventClose);

  @override
  Future<void> waitUntilReadyToShow(
    WindowOptions options,
    Future<void> Function() onReady,
  ) =>
      windowManager.waitUntilReadyToShow(options, onReady);

  @override
  void addListener(WindowListener listener) =>
      windowManager.addListener(listener);

  @override
  void removeListener(WindowListener listener) =>
      windowManager.removeListener(listener);
}
