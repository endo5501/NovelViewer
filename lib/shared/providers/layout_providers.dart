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

/// Width at or above which the search results stand beside the text.
///
/// The file browser is in a drawer at every width, so this decides one thing:
/// whether the search results are a column of the body or an `endDrawer` over
/// it.
///
/// 800 is the width the desktop build already treats as the smallest it will
/// restore a window to: `kMinimumWindowSize` raises any stored sliver to it.
/// Reusing it here makes the fold a continuation of that judgement rather than
/// a tuned number. The constant is repeated rather than imported so that
/// `shared/` keeps no dependency on a feature; a test asserts the two stay
/// equal.
///
/// Nothing stops a reader dragging a desktop window narrower than this — no
/// minimum size is imposed on the native window — and when they do they get
/// the narrow layout, which is the point: below it the 300pt of search results
/// crowd the text they are meant to be found in.
///
/// Exposed as a provider so a widget test can render either layout by
/// overriding it, instead of resizing the test viewport.
final shellBreakpointProvider = Provider<double>((ref) => 800);
