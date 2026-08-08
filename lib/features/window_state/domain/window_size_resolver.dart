import 'dart:ui';

import 'package:novel_viewer/features/window_state/domain/window_state.dart';

/// Size the native Windows runner creates the window at
/// (`windows/runner/main.cpp`). Used when nothing usable is stored.
const Size kDefaultWindowSize = Size(1280, 720);

/// Floor for a restored window, so a stored sliver can't produce an unusable
/// three-column layout.
const Size kMinimumWindowSize = Size(800, 600);

/// Resolves the size to open the window at.
///
/// [workArea] is the primary display's visible size in *logical* pixels
/// (`Display.visibleSize`, which the Windows plugin divides by the scale
/// factor), matching the unit `window_manager` expects. Pass null when it can't
/// be determined; the clamp is then skipped.
///
/// Rules, applied in order:
/// 1. No stored size -> [kDefaultWindowSize].
/// 2. A non-positive or non-finite axis -> [kDefaultWindowSize].
/// 3. Axes below [kMinimumWindowSize] are raised to it.
/// 4. Axes exceeding [workArea] are clamped to it.
/// 5. Rule 4 wins over rule 3: fitting on screen matters more than the
///    minimum, otherwise a small display would get an unreachable title bar.
Size resolveWindowSize(WindowState state, Size? workArea) {
  final stored = _storedSize(state);
  final base = stored ?? kDefaultWindowSize;

  var width = base.width < kMinimumWindowSize.width
      ? kMinimumWindowSize.width
      : base.width;
  var height = base.height < kMinimumWindowSize.height
      ? kMinimumWindowSize.height
      : base.height;

  if (workArea != null) {
    if (workArea.width.isFinite && workArea.width > 0) {
      width = width > workArea.width ? workArea.width : width;
    }
    if (workArea.height.isFinite && workArea.height > 0) {
      height = height > workArea.height ? workArea.height : height;
    }
  }

  return Size(width, height);
}

Size? _storedSize(WindowState state) {
  if (!state.hasSize) return null;
  final width = state.width!;
  final height = state.height!;
  if (!_isUsable(width) || !_isUsable(height)) return null;
  return Size(width, height);
}

bool _isUsable(double value) => value.isFinite && value > 0;
