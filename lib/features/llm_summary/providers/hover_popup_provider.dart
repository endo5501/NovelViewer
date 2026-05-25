import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/domain/hover_token.dart';

export 'package:novel_viewer/features/llm_summary/domain/hover_token.dart'
    show HoverToken;

/// Brief window during which a `hideIfShowing` request is deferred so the
/// pointer can travel from a marked span into the popup widget itself
/// (e.g. to click the snapshot navigator or open the re-analysis dropdown).
const _kHideGracePeriod = Duration(milliseconds: 150);

class HoverPopupState {
  final String? word;
  final Offset? position;
  final HoverToken? hoverToken;

  /// Which snapshot the popup is currently showing. `null` means "use the
  /// default selection rule" (most recent past, or earliest future as a
  /// fallback). User interaction with the snapshot navigator sets this to a
  /// concrete `coveredUpToEpisode` value.
  final int? activeEpisode;

  const HoverPopupState.hidden()
      : word = null,
        position = null,
        hoverToken = null,
        activeEpisode = null;

  const HoverPopupState.visible({
    required String this.word,
    required Offset this.position,
    required HoverToken this.hoverToken,
    this.activeEpisode,
  });

  bool get isVisible => word != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoverPopupState &&
          other.word == word &&
          other.position == position &&
          other.hoverToken == hoverToken &&
          other.activeEpisode == activeEpisode;

  @override
  int get hashCode => Object.hash(word, position, hoverToken, activeEpisode);
}

class HoverPopupNotifier extends Notifier<HoverPopupState> {
  Timer? _hideTimer;
  bool _popupHovered = false;

  /// True while a popup-owned child overlay (currently the reanalyze
  /// dropdown) is open. The pointer is briefly OUTSIDE the popup's
  /// `MouseRegion` while traveling onto a menu item, so without this latch
  /// the grace-period timer would hide the popup and the user could never
  /// reach the menu options. Mirrors the role of `_popupHovered` but is
  /// driven by `onChildMenuOpen` / `onChildMenuClose` instead of
  /// `onPopupEnter` / `onPopupExit`.
  bool _childMenuOpen = false;

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
    _popupHovered = false;
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
    _childMenuOpen = false;
    state = const HoverPopupState.hidden();
  }

  void hideIfShowing(HoverToken token) {
    if (state.hoverToken != token) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(_kHideGracePeriod, () {
      if (_popupHovered || _childMenuOpen) return;
      if (state.hoverToken == token) {
        state = const HoverPopupState.hidden();
      }
    });
  }

  void onPopupEnter() {
    _popupHovered = true;
    _hideTimer?.cancel();
  }

  void onPopupExit() {
    _popupHovered = false;
    // Suppress the immediate-hide when an owned child menu is open: the
    // pointer is briefly outside the popup's MouseRegion as it travels onto
    // a menu item, and dismissing the popup mid-travel would tear down the
    // menu too. The hide will fire from onChildMenuClose if appropriate.
    if (_childMenuOpen) return;
    _hideTimer?.cancel();
    state = const HoverPopupState.hidden();
  }

  /// Mark a popup-owned child overlay (e.g. the reanalyze dropdown) as open.
  /// Cancels any pending grace-period hide so the popup survives the pointer
  /// leaving its own MouseRegion to enter the menu.
  void onChildMenuOpen() {
    _childMenuOpen = true;
    _hideTimer?.cancel();
  }

  /// Mark the child overlay closed. If the pointer is also outside the
  /// popup body, hide immediately (the user has clearly moved on); otherwise
  /// let the popup's own MouseRegion govern the next hide.
  void onChildMenuClose() {
    _childMenuOpen = false;
    if (!_popupHovered) {
      _hideTimer?.cancel();
      state = const HoverPopupState.hidden();
    }
  }

  /// Update which snapshot the popup is displaying. Pass `null` to revert to
  /// the default snapshot selection rule (used when the popup re-opens or
  /// after a re-analysis invalidates the cache).
  void setActiveEpisode(int? episode) {
    if (!state.isVisible) return;
    state = HoverPopupState.visible(
      word: state.word!,
      position: state.position!,
      hoverToken: state.hoverToken!,
      activeEpisode: episode,
    );
  }
}

final hoverPopupProvider =
    NotifierProvider<HoverPopupNotifier, HoverPopupState>(
  HoverPopupNotifier.new,
);
