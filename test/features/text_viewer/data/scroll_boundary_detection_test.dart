import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/scroll_boundary_detection.dart';

/// The horizontal viewer learns about drag-driven input (trackpad, touch) only
/// through scroll notifications: a trackpad swipe arrives as
/// `PointerPanZoomUpdateEvent`, which never reaches `onPointerSignal`.
///
/// Which notification reports the push past an edge depends on the platform's
/// physics, so both shapes have to be understood:
///   - Bouncing (macOS, iOS): the offset is accepted, so a
///     `ScrollUpdateNotification` reports `pixels` beyond the extent.
///   - Clamping (Windows, Linux): the offset is refused, so `pixels` stays at
///     the extent and an `OverscrollNotification` reports the remainder.
void main() {
  group('bouncing physics — position reported beyond the extent', () {
    test('a drag past the end crosses to the next episode', () {
      expect(
        resolveScrollBoundary(
          pixels: 3862,
          minScrollExtent: 0,
          maxScrollExtent: 3832,
          isDragging: true,
        ),
        ScrollBoundaryOutcome.crossToNext,
      );
    });

    test('a drag past the start crosses to the previous episode', () {
      expect(
        resolveScrollBoundary(
          pixels: -24,
          minScrollExtent: 0,
          maxScrollExtent: 3832,
          isDragging: true,
        ),
        ScrollBoundaryOutcome.crossToPrevious,
      );
    });

    test('the bounce-back after the finger lifts is ignored', () {
      // Ballistic settle: still beyond the extent, but the user is no longer
      // pushing. Treating it as input would arm a hint nobody asked for.
      expect(
        resolveScrollBoundary(
          pixels: 3846,
          minScrollExtent: 0,
          maxScrollExtent: 3832,
          isDragging: false,
        ),
        ScrollBoundaryOutcome.ignore,
      );
    });

    test(
      'landing exactly on the extent neither crosses nor drops the hint',
      () {
        // The last frame of the bounce. A drop here would erase the hint the
        // push just armed.
        expect(
          resolveScrollBoundary(
            pixels: 3832,
            minScrollExtent: 0,
            maxScrollExtent: 3832,
            isDragging: false,
          ),
          ScrollBoundaryOutcome.ignore,
        );
      },
    );
  });

  group('clamping physics — overscroll reported separately', () {
    test('a drag past the end crosses to the next episode', () {
      expect(
        resolveScrollBoundary(
          pixels: 3832,
          minScrollExtent: 0,
          maxScrollExtent: 3832,
          isDragging: true,
          overscroll: 30,
        ),
        ScrollBoundaryOutcome.crossToNext,
      );
    });

    test('a drag past the start crosses to the previous episode', () {
      expect(
        resolveScrollBoundary(
          pixels: 0,
          minScrollExtent: 0,
          maxScrollExtent: 3832,
          isDragging: true,
          overscroll: -30,
        ),
        ScrollBoundaryOutcome.crossToPrevious,
      );
    });

    test('overscroll from a fling rather than a finger is ignored', () {
      expect(
        resolveScrollBoundary(
          pixels: 3832,
          minScrollExtent: 0,
          maxScrollExtent: 3832,
          isDragging: false,
          overscroll: 30,
        ),
        ScrollBoundaryOutcome.ignore,
      );
    });
  });

  group('movement inside the file', () {
    test('a position strictly inside the extents drops the hint', () {
      expect(
        resolveScrollBoundary(
          pixels: 1900,
          minScrollExtent: 0,
          maxScrollExtent: 3832,
          isDragging: true,
        ),
        ScrollBoundaryOutcome.dropHint,
      );
    });

    test('it drops the hint even without a finger down', () {
      // A search-result or bookmark jump moves the body with no drag at all.
      expect(
        resolveScrollBoundary(
          pixels: 1900,
          minScrollExtent: 0,
          maxScrollExtent: 3832,
          isDragging: false,
        ),
        ScrollBoundaryOutcome.dropHint,
      );
    });

    test('content that fits the viewport never drops the hint', () {
      // min == max == 0, so every position is an edge; there is no "inside"
      // to move within.
      expect(
        resolveScrollBoundary(
          pixels: 0,
          minScrollExtent: 0,
          maxScrollExtent: 0,
          isDragging: false,
        ),
        ScrollBoundaryOutcome.ignore,
      );
    });

    test('a single-screen file still crosses on a drag past the edge', () {
      expect(
        resolveScrollBoundary(
          pixels: 12,
          minScrollExtent: 0,
          maxScrollExtent: 0,
          isDragging: true,
        ),
        ScrollBoundaryOutcome.crossToNext,
      );
    });
  });
}
