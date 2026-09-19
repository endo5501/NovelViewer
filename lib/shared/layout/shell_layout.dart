/// Which of the two shell shapes the main screen presents.
///
/// The app is a reader, so the question this answers is "how much room is left
/// for the body text", not "which device is this". A window narrow enough that
/// the fixed side columns would crowd the text gets [narrow], where those
/// columns move into drawers and the viewer takes the whole body; anything
/// wider keeps the three-column [wide] arrangement.
///
/// Deciding by width rather than by platform keeps the application's single
/// `dart:io` `Platform` read — the one in the capability provider — the only
/// one there is, and it lets a widget test render either shape, which reading
/// the platform would not.
enum ShellLayout {
  /// Side panels live in drawers; the text viewer owns the full body width.
  narrow,

  /// The three-column row: left column, text viewer, optional right column.
  wide,
}

/// The one mapping from a display width to the shell's shape.
///
/// [breakpoint] belongs to the wide side: it is the narrowest width at which
/// the three-column layout is supported, not the first width that fails.
ShellLayout resolveShellLayout({
  required double width,
  required double breakpoint,
}) => width < breakpoint ? ShellLayout.narrow : ShellLayout.wide;

/// The widest the file browser drawer is allowed to get.
///
/// The drawer holds a list of file names, not a second body, so past this
/// width the extra room buys no more of the name and only hides more of the
/// text behind it. 560 fits the long episode names that made the old fixed
/// 250pt column unreadable.
const double kFileBrowserDrawerMaxWidth = 560;

/// How much of the display the drawer leaves uncovered.
///
/// On a display too narrow to reach the cap the drawer would otherwise take
/// the whole screen, which reads as a new page rather than as a panel over
/// the text. Leaving this strip keeps it legible as an overlay.
const double kFileBrowserDrawerGutter = 64;

/// The one mapping from a display width to the file browser drawer's width.
///
/// Kept beside [resolveShellLayout] and pure for the same reason: the home
/// screen stays the only place that reads `MediaQuery`, and the boundaries —
/// the cap, the width that reaches it, a phone in portrait — are unit
/// testable without building a widget.
double fileBrowserDrawerWidth({required double displayWidth}) {
  final available = displayWidth - kFileBrowserDrawerGutter;
  return available < kFileBrowserDrawerMaxWidth
      ? available
      : kFileBrowserDrawerMaxWidth;
}
