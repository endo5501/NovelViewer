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
