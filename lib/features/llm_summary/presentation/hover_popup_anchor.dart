import 'package:flutter/painting.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';

/// Approximate popup width used for edge-flip math. The popup widget caps
/// itself at this value, so it is a tight upper bound for the real laid-out
/// width.
const double kHoverPopupApproxWidth = 320.0;

/// Approximate popup height for edge-flip math. The popup may be shorter
/// than this, but never meaningfully taller: 2-3 lines of summary plus
/// the optional toggle and reference warning.
const double kHoverPopupApproxHeight = 140.0;

/// Gap between the pointer and the popup's near edge.
const double kHoverPopupGap = 16.0;

/// Top-left position of the popup, in global screen coordinates, for the
/// given display [mode] and pointer location. The returned offset is what
/// callers pass to a `Positioned(left:..., top:...)` over the root overlay.
///
/// Horizontal mode: popup goes down-right of the pointer (no edge flips —
/// matches the archived horizontal-only behavior).
///
/// Vertical mode: popup goes up-right of the pointer by default so it
/// floats over already-read columns (which are to the right under RTL
/// column flow) and away from the next character in the reading direction.
/// If the up-right placement would overflow the screen's right or top
/// edge, the affected axis flips: right-overflow → popup left of pointer,
/// top-overflow → popup below pointer.
({double left, double top}) computePopupAnchor({
  required TextDisplayMode mode,
  required Offset pointer,
  required Size screenSize,
}) {
  if (mode == TextDisplayMode.horizontal) {
    // Horizontal mode keeps the simple "down-right of pointer" anchor with
    // no flipping and no clamping — this matches the archived behavior.
    return (left: pointer.dx + kHoverPopupGap, top: pointer.dy + kHoverPopupGap);
  }

  // Vertical mode defaults.
  var left = pointer.dx + kHoverPopupGap;
  var top = pointer.dy - kHoverPopupGap - kHoverPopupApproxHeight;

  // Right-edge overflow → flip horizontally so the popup sits to the left.
  if (left + kHoverPopupApproxWidth > screenSize.width) {
    left = pointer.dx - kHoverPopupGap - kHoverPopupApproxWidth;
  }
  // Top-edge overflow → flip vertically so the popup sits below.
  if (top < 0) {
    top = pointer.dy + kHoverPopupGap;
  }

  // Final clamps so a pathologically narrow / short viewport that breaks
  // the flip can still keep the popup origin on-screen. The popup body may
  // still overflow if it cannot physically fit — we anchor the top-left
  // on-screen and let the body clip naturally.
  final maxLeft = (screenSize.width - kHoverPopupApproxWidth).clamp(
    0.0,
    double.infinity,
  );
  final maxTop = (screenSize.height - kHoverPopupApproxHeight).clamp(
    0.0,
    double.infinity,
  );
  left = left.clamp(0.0, maxLeft);
  top = top.clamp(0.0, maxTop);

  return (left: left, top: top);
}
