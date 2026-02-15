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
  if (duration <= Duration.zero) return null;

  final dx = endPosition.dx - startPosition.dx;
  final dy = endPosition.dy - startPosition.dy;
  final absDx = dx.abs();
  final absDy = dy.abs();

  if (absDx <= kSwipeMinDistance) return null;
  if (absDx <= absDy) return null;

  final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
  if (seconds <= 0) return null;

  final velocity = absDx / seconds;
  if (velocity <= kSwipeMinVelocity) return null;

  return dx < 0 ? SwipeDirection.left : SwipeDirection.right;
}

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
