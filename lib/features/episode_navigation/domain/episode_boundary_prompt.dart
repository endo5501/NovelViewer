import 'dart:async';

import 'package:flutter/foundation.dart';

/// Which neighbour a boundary input is reaching for.
enum EpisodeBoundaryDirection { next, previous }

/// The two-step confirmation shared by the vertical and horizontal viewers.
///
/// A viewer feeds it inputs it could not satisfy inside the file — the page
/// index was pinned at the first/last page, or the scroll view was already
/// parked at its boundary — and this decides whether that input arms a hint or
/// confirms the episode switch. Anything the viewer *could* satisfy in-file is
/// reported through [reset], which drops a pending hint.
///
/// It owns no navigation: [hitBoundary] returns `true` and the caller performs
/// the switch. That keeps this free of Riverpod and testable with `fake_async`
/// alone.
class EpisodeBoundaryPrompt extends ChangeNotifier {
  EpisodeBoundaryPrompt({
    this.promptTimeout = const Duration(seconds: 4),
    this.confirmCooldown = const Duration(milliseconds: 300),
  });

  /// How long an armed hint survives without further input.
  final Duration promptTimeout;

  /// How long after arming a hint the same direction cannot confirm it. A
  /// single wheel turn, key repeat or overscroll fling emits a burst of
  /// events; without this one gesture would both arm and confirm.
  final Duration confirmCooldown;

  EpisodeBoundaryDirection? _pending;
  Timer? _timeoutTimer;
  Timer? _cooldownTimer;

  /// The armed direction, or null while idle.
  EpisodeBoundaryDirection? get pending => _pending;

  bool get _inCooldown => _cooldownTimer?.isActive ?? false;

  /// Feeds one boundary input in [direction]. [hasAdjacent] says whether a
  /// neighbouring file exists that way.
  ///
  /// Returns true when the caller should navigate; the prompt is already
  /// disarmed by then.
  bool hitBoundary(
    EpisodeBoundaryDirection direction, {
    required bool hasAdjacent,
  }) {
    // Nothing to move to: neither arm a hint nor disturb one already armed in
    // the other direction.
    if (!hasAdjacent) return false;

    if (_pending == direction) {
      // Still inside the cooldown, so this is the same gesture that armed the
      // hint rather than a second, deliberate input. Ignore it without
      // touching the timeout — the hint expires 4s after arming, not 4s after
      // the last event of a fling.
      if (_inCooldown) return false;
      _disarm();
      return true;
    }

    _arm(direction);
    return false;
  }

  /// Drops a pending hint. Called when the viewer moved inside the file, when
  /// the file changed, or when the hint no longer applies.
  void reset() {
    if (_pending == null) {
      // Still clear the cooldown so a later arm is not silently suppressed.
      _cooldownTimer?.cancel();
      _cooldownTimer = null;
      return;
    }
    _disarm();
    notifyListeners();
  }

  void _arm(EpisodeBoundaryDirection direction) {
    _timeoutTimer?.cancel();
    _cooldownTimer?.cancel();
    _pending = direction;
    _cooldownTimer = Timer(confirmCooldown, () {});
    _timeoutTimer = Timer(promptTimeout, () {
      _disarm();
      notifyListeners();
    });
    notifyListeners();
  }

  void _disarm() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _pending = null;
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
