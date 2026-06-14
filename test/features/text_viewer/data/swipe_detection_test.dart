import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/swipe_detection.dart';

void main() {
  group('detectSwipeFromDrag', () {
    test('detects left swipe with sufficient distance and velocity', () {
      final result = detectSwipeFromDrag(
        startPosition: const Offset(200, 100),
        endPosition: const Offset(100, 100),
        velocity: const Velocity(pixelsPerSecond: Offset(-500, 0)),
      );
      expect(result, SwipeDirection.left);
    });

    test('detects right swipe with sufficient distance and velocity', () {
      final result = detectSwipeFromDrag(
        startPosition: const Offset(100, 100),
        endPosition: const Offset(200, 100),
        velocity: const Velocity(pixelsPerSecond: Offset(500, 0)),
      );
      expect(result, SwipeDirection.right);
    });

    test('returns null when horizontal distance is below threshold', () {
      final result = detectSwipeFromDrag(
        startPosition: const Offset(100, 100),
        endPosition: const Offset(130, 100),
        velocity: const Velocity(pixelsPerSecond: Offset(-500, 0)),
      );
      expect(result, isNull);
    });

    test('returns null when vertical displacement exceeds horizontal', () {
      final result = detectSwipeFromDrag(
        startPosition: const Offset(100, 100),
        endPosition: const Offset(160, 300),
        velocity: const Velocity(pixelsPerSecond: Offset(-500, -1000)),
      );
      expect(result, isNull);
    });

    test('detects swipe with zero velocity when distance exceeds fallback threshold', () {
      // Desktop scenario: user stops before releasing, velocity is zero
      // Distance = 100px > kSwipeMinDistanceWithoutFling (80px)
      final result = detectSwipeFromDrag(
        startPosition: const Offset(200, 100),
        endPosition: const Offset(100, 100),
        velocity: Velocity.zero,
      );
      expect(result, SwipeDirection.left);
    });

    test('returns null with zero velocity when distance is below fallback threshold', () {
      // Distance = 60px, below kSwipeMinDistanceWithoutFling (80px)
      final result = detectSwipeFromDrag(
        startPosition: const Offset(100, 100),
        endPosition: const Offset(160, 100),
        velocity: Velocity.zero,
      );
      expect(result, isNull);
    });
  });
}
