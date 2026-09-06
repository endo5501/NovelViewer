import 'package:flutter_riverpod/flutter_riverpod.dart';

class RightColumnVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final rightColumnVisibleProvider =
    NotifierProvider<RightColumnVisibleNotifier, bool>(
      RightColumnVisibleNotifier.new,
    );

/// Width at or above which the shell keeps its three-column layout.
///
/// 800 is the width the desktop build already treats as the smallest one the
/// three columns fit in: `kMinimumWindowSize` raises any restored window to it
/// so a stored sliver cannot come back as an unusable three-column layout.
/// Reusing it here makes the fold a continuation of that judgement rather than
/// a tuned number. The constant is repeated rather than imported so that
/// `shared/` keeps no dependency on a feature; a test asserts the two stay
/// equal.
///
/// Nothing stops a reader dragging a desktop window narrower than this — no
/// minimum size is imposed on the native window — and when they do they get
/// the narrow layout, which is the point: at 800pt the old row left 248pt of
/// text once the search results were open.
///
/// Exposed as a provider so a widget test can render either layout by
/// overriding it, instead of resizing the test viewport.
final shellBreakpointProvider = Provider<double>((ref) => 800);
