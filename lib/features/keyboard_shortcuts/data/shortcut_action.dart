/// Customizable keyboard shortcut actions.
///
/// Each value maps to a single key combination that the user can rebind and
/// that is persisted. Page navigation (`nextPage`/`prevPage`) is intentionally
/// NOT part of this enum: its physical keys depend on the writing-mode
/// orientation (vertical = left/right, horizontal = up/down), so it cannot be
/// expressed as a single rebindable activator. Page navigation is handled by
/// fixed, viewer-scoped shortcuts instead (see `NextPageIntent`/`PrevPageIntent`).
enum ShortcutAction {
  search,
  bookmark,
  ttsToggle,
  switchPane,
}
