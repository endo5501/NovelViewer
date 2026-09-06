/// What a scroll notification means for the horizontal viewer's boundary
/// two-step confirmation.
enum ScrollBoundaryOutcome {
  /// Nothing to do: the body did not move within the file, and nobody is
  /// pushing past an edge.
  ignore,

  /// The reader moved inside the file, so an armed hint no longer applies.
  dropHint,

  /// A push past the end: feed it to the prompt as a next-episode input.
  crossToNext,

  /// A push past the start: feed it to the prompt as a previous-episode input.
  crossToPrevious,
}

/// Classifies one scroll notification.
///
/// This exists because a trackpad swipe (and, on a touch screen, a finger)
/// arrives as `PointerPanZoomUpdateEvent` / `PointerMoveEvent`, neither of
/// which is a `PointerSignalEvent` — so `onPointerSignal`, which catches the
/// mouse wheel, never sees them. Scroll notifications are the one place every
/// input converges.
///
/// The platform's physics decides which notification reports a push past an
/// edge, so both shapes are handled:
///
/// - Bouncing (macOS, iOS): `applyBoundaryConditions` returns 0, the offset is
///   accepted, and [pixels] is reported beyond the extent by a
///   `ScrollUpdateNotification`. Pass [overscroll] as null.
/// - Clamping (Windows, Linux): the offset is refused, [pixels] stays pinned at
///   the extent, and an `OverscrollNotification` carries the remainder. Pass it
///   as [overscroll].
///
/// [isDragging] is the notification's `dragDetails != null`. A ballistic settle
/// — the bounce-back after the finger lifts — is still beyond the extent but is
/// not the reader asking for anything, so it must not arm a hint.
ScrollBoundaryOutcome resolveScrollBoundary({
  required double pixels,
  required double minScrollExtent,
  required double maxScrollExtent,
  required bool isDragging,
  double? overscroll,
}) {
  if (overscroll != null) {
    if (!isDragging || overscroll == 0) return ScrollBoundaryOutcome.ignore;
    return overscroll > 0
        ? ScrollBoundaryOutcome.crossToNext
        : ScrollBoundaryOutcome.crossToPrevious;
  }

  if (pixels > maxScrollExtent) {
    return isDragging
        ? ScrollBoundaryOutcome.crossToNext
        : ScrollBoundaryOutcome.ignore;
  }
  if (pixels < minScrollExtent) {
    return isDragging
        ? ScrollBoundaryOutcome.crossToPrevious
        : ScrollBoundaryOutcome.ignore;
  }
  // Resting exactly on an extent is not movement inside the file: dropping the
  // hint there would erase the one the push just armed, on the last frame of
  // the bounce-back.
  if (pixels > minScrollExtent && pixels < maxScrollExtent) {
    return ScrollBoundaryOutcome.dropHint;
  }
  return ScrollBoundaryOutcome.ignore;
}
