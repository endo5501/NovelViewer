import 'package:flutter/gestures.dart';

/// Minimum horizontal displacement in pixels to recognize a swipe.
const kSwipeMinDistance = 50.0;

/// Minimum horizontal velocity in pixels per second to recognize a swipe.
const kSwipeMinVelocity = 200.0;

/// Minimum horizontal displacement when velocity is unavailable (desktop).
/// On desktop, DragEndDetails.velocity may be zero when the user stops
/// moving before releasing the mouse button, so we use a larger distance
/// threshold as a fallback.
const kSwipeMinDistanceWithoutFling = 80.0;

enum SwipeDirection { left, right }

/// Detects a swipe from pan gesture data, using the end [velocity] from
/// [DragEndDetails].
///
/// On desktop, [DragEndDetails.velocity] may be [Velocity.zero] when the
/// user stops moving before releasing the mouse button (no fling detected).
/// In that case, a larger distance threshold ([kSwipeMinDistanceWithoutFling])
/// is used instead of requiring velocity.
///
/// Returns [SwipeDirection.left] or [SwipeDirection.right] if the gesture
/// constitutes a swipe, or `null` otherwise.
SwipeDirection? detectSwipeFromDrag({
  required Offset startPosition,
  required Offset endPosition,
  required Velocity velocity,
}) {
  final dx = endPosition.dx - startPosition.dx;
  final dy = endPosition.dy - startPosition.dy;
  final absDx = dx.abs();
  final absDy = dy.abs();

  if (absDx <= absDy) return null;

  final hasVelocity = velocity.pixelsPerSecond.dx.abs() > kSwipeMinVelocity;
  final requiredDistance =
      hasVelocity ? kSwipeMinDistance : kSwipeMinDistanceWithoutFling;

  if (absDx <= requiredDistance) return null;

  return dx < 0 ? SwipeDirection.left : SwipeDirection.right;
}
