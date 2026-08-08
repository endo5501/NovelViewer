import 'dart:async';
import 'dart:ui';

import 'package:novel_viewer/features/window_state/data/window_controller.dart';
import 'package:window_manager/window_manager.dart';

/// In-memory [WindowController] for unit tests.
///
/// Lets a test set what the "OS" reports (size, maximized, visibility) and
/// observe what the code under test did to the window, without a method
/// channel.
class FakeWindowController implements WindowController {
  Size size = const Size(1280, 720);
  bool maximized = false;
  bool minimized = false;

  /// Number of [isVisible] polls before the window reports itself visible,
  /// mimicking the runner showing it on Flutter's first frame.
  int visibleAfterPolls = 0;

  /// Makes the corresponding call fail, to exercise error paths.
  bool throwOnGetSize = false;
  bool throwOnDestroy = false;
  bool throwOnClose = false;
  bool throwOnSetSize = false;

  /// When set, [isMaximized] blocks on it, letting a test hold one flush open
  /// while another is queued behind it.
  Completer<void>? flushGate;

  int visibilityPolls = 0;
  int destroyCount = 0;
  int closeCount = 0;
  int maximizeCount = 0;
  bool? preventClose;
  Size? sizeSetByCaller;

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
  Future<bool> isMaximized() async {
    if (flushGate != null) await flushGate!.future;
    return maximized;
  }

  @override
  Future<bool> isVisible() async => visibilityPolls++ >= visibleAfterPolls;

  @override
  Future<bool> isMinimized() async => minimized;

  @override
  Future<void> close() async {
    calls.add('close');
    closeCount++;
    if (throwOnClose) throw StateError('close failed');
  }

  @override
  Future<void> setSize(Size size) async {
    calls.add('setSize');
    if (throwOnSetSize) throw StateError('setSize failed');
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
  Future<void> destroy() async {
    calls.add('destroy');
    destroyCount++;
    if (throwOnDestroy) throw StateError('destroy failed');
  }

  @override
  Future<void> setPreventClose(bool preventClose) async {
    calls.add('setPreventClose($preventClose)');
    this.preventClose = preventClose;
  }

  @override
  void addListener(WindowListener listener) => listeners.add(listener);

  @override
  void removeListener(WindowListener listener) => listeners.remove(listener);
}
