import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/domain/hover_token.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

export 'package:novel_viewer/features/llm_summary/domain/hover_token.dart'
    show HoverToken;

/// Brief window during which a `hideIfShowing` request is deferred so the
/// pointer can travel from a marked span into the popup widget itself
/// (e.g. to click the no-spoiler / spoiler toggle pill). If the pointer
/// reaches the popup within this window, [HoverPopupNotifier.onPopupEnter]
/// cancels the pending hide.
const _kHideGracePeriod = Duration(milliseconds: 150);

class HoverPopupState {
  final String? word;
  final Offset? position;
  final HoverToken? hoverToken;
  final SummaryType activeType;

  const HoverPopupState.hidden()
      : word = null,
        position = null,
        hoverToken = null,
        activeType = SummaryType.noSpoiler;

  const HoverPopupState.visible({
    required String this.word,
    required Offset this.position,
    required HoverToken this.hoverToken,
    this.activeType = SummaryType.noSpoiler,
  });

  bool get isVisible => word != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoverPopupState &&
          other.word == word &&
          other.position == position &&
          other.hoverToken == hoverToken &&
          other.activeType == activeType;

  @override
  int get hashCode => Object.hash(word, position, hoverToken, activeType);
}

class HoverPopupNotifier extends Notifier<HoverPopupState> {
  Timer? _hideTimer;
  // The pointer is currently inside the popup widget itself, so any pending
  // hide should be suppressed and the popup must stay visible until
  // [onPopupExit] fires.
  bool _popupHovered = false;

  @override
  HoverPopupState build() {
    ref.onDispose(() {
      _hideTimer?.cancel();
    });
    return const HoverPopupState.hidden();
  }

  void show({
    required String word,
    required Offset position,
    required HoverToken token,
  }) {
    _hideTimer?.cancel();
    // A fresh popup never inherits the previous popup's hover latch — if
    // the old popup was hovered when something programmatically hid it
    // (mode switch, page jump), that latch would otherwise suppress the
    // grace-period hide of the new popup.
    _popupHovered = false;
    // Skip the state write when the same span is already active, so sub-pixel
    // pointer wobble inside one marked occurrence does not churn the
    // OverlayEntry via the host's ref.listen. Different occurrences of the
    // same word produce different tokens and DO update.
    if (state.hoverToken == token) return;
    state = HoverPopupState.visible(
      word: word,
      position: position,
      hoverToken: token,
    );
  }

  void hide() {
    _hideTimer?.cancel();
    _popupHovered = false;
    state = const HoverPopupState.hidden();
  }

  /// Schedule a deferred hide of the popup when the pointer leaves the
  /// marked span identified by [token]. The hide is deferred by
  /// [_kHideGracePeriod] so the pointer can travel into the popup widget
  /// (e.g. to interact with the no-spoiler / spoiler toggle); within that
  /// window, [onPopupEnter] cancels the pending hide. Calling this for a
  /// token that does not match the currently visible popup is a no-op,
  /// which together with the same-token guard in [show] handles
  /// cross-event ordering when the pointer transitions between adjacent
  /// marked spans.
  void hideIfShowing(HoverToken token) {
    if (state.hoverToken != token) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(_kHideGracePeriod, () {
      if (_popupHovered) return;
      if (state.hoverToken == token) {
        state = const HoverPopupState.hidden();
      }
    });
  }

  /// The pointer has entered the popup widget itself. Cancel any pending
  /// hide so the popup remains visible while the user interacts with it.
  void onPopupEnter() {
    _popupHovered = true;
    _hideTimer?.cancel();
  }

  /// The pointer has left the popup widget. Hide immediately — the user has
  /// clearly moved on, so the grace period does not apply.
  void onPopupExit() {
    _popupHovered = false;
    _hideTimer?.cancel();
    state = const HoverPopupState.hidden();
  }

  void setSummaryType(SummaryType type) {
    if (!state.isVisible) return;
    state = HoverPopupState.visible(
      word: state.word!,
      position: state.position!,
      hoverToken: state.hoverToken!,
      activeType: type,
    );
  }
}

final hoverPopupProvider =
    NotifierProvider<HoverPopupNotifier, HoverPopupState>(
  HoverPopupNotifier.new,
);
