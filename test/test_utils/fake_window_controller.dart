import 'dart:ui';

import 'package:novel_viewer/features/window_state/data/window_controller.dart';
import 'package:window_manager/window_manager.dart';

/// In-memory [WindowController] for unit tests.
///
/// Lets a test set what the "OS" reports (size, maximized) and observe what the
/// code under test did to the window, without a method channel.
class FakeWindowController implements WindowController {
  Size size = const Size(1280, 720);
  bool maximized = false;

  /// Makes [getSize] fail, to exercise error paths.
  bool throwOnGetSize = false;

  int destroyCount = 0;
  int maximizeCount = 0;
  int showCount = 0;
  bool? preventClose;
  Size? sizeSetByCaller;
  WindowOptions? readyOptions;

  /// Records the order of the calls that matter for restore correctness.
  final List<String> calls = <String>[];

  final List<WindowListener> listeners = <WindowListener>[];

  @override
  Future<Size> getSize() async {
    if (throwOnGetSize) {
      throw StateError('getSize failed');
    }
    return size;
  }

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<void> setSize(Size size) async {
    calls.add('setSize');
    sizeSetByCaller = size;
    this.size = size;
  }

  @override
  Future<void> maximize() async {
    calls.add('maximize');
    maximizeCount++;
    maximized = true;
  }

  @override
  Future<void> show() async {
    calls.add('show');
    showCount++;
  }

  @override
  Future<void> destroy() async {
    calls.add('destroy');
    destroyCount++;
  }

  @override
  Future<void> setPreventClose(bool preventClose) async {
    this.preventClose = preventClose;
  }

  @override
  Future<void> waitUntilReadyToShow(
    WindowOptions options,
    Future<void> Function() onReady,
  ) async {
    readyOptions = options;
    calls.add('waitUntilReadyToShow');
    if (options.size != null) {
      size = options.size!;
    }
    await onReady();
  }

  @override
  void addListener(WindowListener listener) => listeners.add(listener);

  @override
  void removeListener(WindowListener listener) => listeners.remove(listener);
}
