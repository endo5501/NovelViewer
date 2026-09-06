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
/// 800 is the minimum window size the desktop build enforces
/// (`kMinimumWindowSize`), chosen there so a restored sliver of a window
/// cannot produce an unusable three-column layout. It is therefore already
/// the narrowest width those columns are supported at, which makes it the
/// principled place to fold them into drawers rather than a tuned number. The
/// constant is repeated rather than imported so that `shared/` keeps no
/// dependency on a feature; a test asserts the two stay equal.
///
/// Exposed as a provider so a widget test can render either layout by
/// overriding it, instead of resizing the test viewport.
final shellBreakpointProvider = Provider<double>((ref) => 800);
