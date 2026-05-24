import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

/// Identifies a specific marked-text occurrence so the hover popup can tell
/// two same-word occurrences apart. Uses the segment-global text range of
/// the mark, which is stable across rebuilds while the mark layout is.
typedef HoverToken = ({int start, int end});

/// State of the hover popup that appears over marked words in the text viewer.
/// A `hidden` state means no popup is shown. A `visible` state carries the
/// word, the global screen position of the hover event, a [HoverToken]
/// identifying the specific occurrence under the pointer, and the currently
/// active summary type (no-spoiler by default).
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
  @override
  HoverPopupState build() => const HoverPopupState.hidden();

  void show({
    required String word,
    required Offset position,
    required HoverToken token,
  }) {
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
    state = const HoverPopupState.hidden();
  }

  /// Hide the popup ONLY when it is currently showing the given [token]. This
  /// guards against cross-event ordering (`enter(B)` arriving before
  /// `exit(A)` when the pointer transitions between adjacent marked spans),
  /// so a stale exit for the previous span does not clobber an already-active
  /// new popup. Per-occurrence tokens also prevent `exit` on one occurrence
  /// of a word from closing the popup that just opened on a different
  /// occurrence of the same word.
  void hideIfShowing(HoverToken token) {
    if (state.hoverToken == token) {
      state = const HoverPopupState.hidden();
    }
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
