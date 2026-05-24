import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

/// State of the hover popup that appears over marked words in the text viewer.
/// A `hidden` state means no popup is shown. A `visible` state carries the
/// word, the global screen position of the hover event, and the currently
/// active summary type (no-spoiler by default).
class HoverPopupState {
  final String? word;
  final Offset? position;
  final SummaryType activeType;

  const HoverPopupState.hidden()
      : word = null,
        position = null,
        activeType = SummaryType.noSpoiler;

  const HoverPopupState.visible({
    required String this.word,
    required Offset this.position,
    this.activeType = SummaryType.noSpoiler,
  });

  bool get isVisible => word != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoverPopupState &&
          other.word == word &&
          other.position == position &&
          other.activeType == activeType;

  @override
  int get hashCode => Object.hash(word, position, activeType);
}

class HoverPopupNotifier extends Notifier<HoverPopupState> {
  @override
  HoverPopupState build() => const HoverPopupState.hidden();

  void show({required String word, required Offset position}) {
    // Skip the state write when the popup is already pointing at the same
    // word, so sub-pixel pointer wobble inside one marked span does not
    // churn the OverlayEntry via the host's ref.listen.
    if (state.word == word) return;
    state = HoverPopupState.visible(word: word, position: position);
  }

  void hide() {
    state = const HoverPopupState.hidden();
  }

  /// Hide the popup ONLY when it is currently showing [word]. This guards
  /// against cross-event ordering (`enter(B)` arriving before `exit(A)` when
  /// the pointer transitions between adjacent marked spans), so a stale exit
  /// for the previous word does not clobber an already-active new popup.
  void hideIfShowing(String word) {
    if (state.word == word) {
      state = const HoverPopupState.hidden();
    }
  }

  void setSummaryType(SummaryType type) {
    if (!state.isVisible) return;
    state = HoverPopupState.visible(
      word: state.word!,
      position: state.position!,
      activeType: type,
    );
  }
}

final hoverPopupProvider =
    NotifierProvider<HoverPopupNotifier, HoverPopupState>(
  HoverPopupNotifier.new,
);
