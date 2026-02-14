import 'dart:ui';

/// Minimum horizontal displacement in pixels to recognize a swipe.
const kSwipeMinDistance = 50.0;

/// Minimum horizontal velocity in pixels per second to recognize a swipe.
const kSwipeMinVelocity = 200.0;

enum SwipeDirection { left, right }

/// Detects whether pointer movement from [startPosition] to [endPosition]
/// over [duration] constitutes a horizontal swipe.
///
/// Returns [SwipeDirection.left] or [SwipeDirection.right] if all conditions
/// are met, or `null` if the gesture is not a swipe.
///
/// A swipe is recognized when:
/// 1. Horizontal displacement exceeds [kSwipeMinDistance]
/// 2. Horizontal displacement exceeds vertical displacement (primarily horizontal)
/// 3. Horizontal velocity exceeds [kSwipeMinVelocity]
SwipeDirection? detectSwipe({
  required Offset startPosition,
  required Offset endPosition,
  required Duration duration,
}) {
  if (duration == Duration.zero) return null;

  final dx = endPosition.dx - startPosition.dx;
  final dy = endPosition.dy - startPosition.dy;
  final absDx = dx.abs();
  final absDy = dy.abs();

  if (absDx <= kSwipeMinDistance) return null;
  if (absDx <= absDy) return null;

  final velocity = absDx / (duration.inMilliseconds / 1000.0);
  if (velocity <= kSwipeMinVelocity) return null;

  return dx < 0 ? SwipeDirection.left : SwipeDirection.right;
}
