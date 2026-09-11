/// Identifies a specific marked-text occurrence so the hover popup can tell
/// two same-word occurrences apart. The notifier only compares tokens for
/// equality, so the precise semantics of `start`/`end` are defined by the
/// caller:
///
/// * **Horizontal mode** uses whole-text offsets, which are stable across
///   rebuilds while the parsed segments are unchanged, and are the same
///   whether the occurrence was reached by hovering it or by tapping it.
///   They come from `MarkSpan.occurrence`, which survives the translation
///   into per-segment coordinates that the rendering does.
/// * **Vertical mode** uses page-local char-entry indices, which are stable
///   within one paginated page; cross-page lookups are not meaningful, so
///   `VerticalTextPage` resets its hover diff state when segments change.
typedef HoverToken = ({int start, int end});
