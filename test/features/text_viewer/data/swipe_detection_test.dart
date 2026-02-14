import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/swipe_detection.dart';

void main() {
  group('detectSwipe', () {
    test('detects left swipe with sufficient distance and velocity', () {
      final result = detectSwipe(
        startPosition: const Offset(200, 100),
        endPosition: const Offset(100, 100),
        duration: const Duration(milliseconds: 200),
      );
      expect(result, SwipeDirection.left);
    });

    test('detects right swipe with sufficient distance and velocity', () {
      final result = detectSwipe(
        startPosition: const Offset(100, 100),
        endPosition: const Offset(200, 100),
        duration: const Duration(milliseconds: 200),
      );
      expect(result, SwipeDirection.right);
    });

    test('returns null when horizontal distance is below threshold', () {
      final result = detectSwipe(
        startPosition: const Offset(100, 100),
        endPosition: const Offset(130, 100),
        duration: const Duration(milliseconds: 100),
      );
      expect(result, isNull);
    });

    test('returns null when velocity is below threshold', () {
      final result = detectSwipe(
        startPosition: const Offset(100, 100),
        endPosition: const Offset(200, 100),
        duration: const Duration(milliseconds: 1000),
      );
      expect(result, isNull);
    });

    test('returns null when vertical displacement exceeds horizontal', () {
      final result = detectSwipe(
        startPosition: const Offset(100, 100),
        endPosition: const Offset(160, 300),
        duration: const Duration(milliseconds: 200),
      );
      expect(result, isNull);
    });

    test('returns null for zero duration', () {
      final result = detectSwipe(
        startPosition: const Offset(100, 100),
        endPosition: const Offset(200, 100),
        duration: Duration.zero,
      );
      expect(result, isNull);
    });

    test('detects swipe at exact threshold values', () {
      // Exactly 51px horizontal, 0px vertical, velocity = 51/0.2 = 255 px/s > 200
      final result = detectSwipe(
        startPosition: const Offset(100, 100),
        endPosition: const Offset(49, 100),
        duration: const Duration(milliseconds: 200),
      );
      expect(result, SwipeDirection.left);
    });

    test('returns null when distance is exactly at threshold boundary', () {
      // Exactly 50px - not exceeding threshold
      final result = detectSwipe(
        startPosition: const Offset(100, 100),
        endPosition: const Offset(50, 100),
        duration: const Duration(milliseconds: 100),
      );
      expect(result, isNull);
    });
  });
}
