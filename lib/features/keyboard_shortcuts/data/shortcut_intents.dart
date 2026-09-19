import 'package:flutter/widgets.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';

/// Intents dispatched by the centralized keyboard-shortcut system.
///
/// The customizable-action intents ([SearchIntent], [BookmarkIntent],
/// [TtsToggleIntent], [ToggleFileBrowserIntent]) are produced by HomeScreen's dynamic
/// `Shortcuts` map. The page-navigation intents ([NextPageIntent],
/// [PrevPageIntent]) are produced by fixed, viewer-scoped `Shortcuts` and are
/// implemented by whichever viewer currently holds focus.

class SearchIntent extends Intent {
  const SearchIntent();
}

class BookmarkIntent extends Intent {
  const BookmarkIntent();
}

class TtsToggleIntent extends Intent {
  const TtsToggleIntent();
}

/// Logical "show or hide the file browser" action. The file browser lives in a
/// drawer at every display width, so this opens the drawer when it is closed
/// and closes it when it is open.
class ToggleFileBrowserIntent extends Intent {
  const ToggleFileBrowserIntent();
}

/// Logical "advance one page" action. Each viewer translates it into its own
/// physical direction (vertical: leftward column, horizontal: scroll down).
class NextPageIntent extends Intent {
  const NextPageIntent();
}

/// Logical "go back one page" action. Each viewer translates it into its own
/// physical direction (vertical: rightward column, horizontal: scroll up).
class PrevPageIntent extends Intent {
  const PrevPageIntent();
}

/// Returns the [Intent] corresponding to a customizable [ShortcutAction].
Intent intentFor(ShortcutAction action) {
  switch (action) {
    case ShortcutAction.search:
      return const SearchIntent();
    case ShortcutAction.bookmark:
      return const BookmarkIntent();
    case ShortcutAction.ttsToggle:
      return const TtsToggleIntent();
    case ShortcutAction.toggleFileBrowser:
      return const ToggleFileBrowserIntent();
  }
}
