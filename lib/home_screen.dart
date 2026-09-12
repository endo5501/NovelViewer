import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/app/selected_file_progress_title_provider.dart';
import 'package:novel_viewer/features/app_update/presentation/update_badge.dart';
import 'package:novel_viewer/features/bookmark/presentation/left_column_panel.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/focus_utils.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_intents.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_host.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_download/providers/download_request_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/features/text_search/presentation/search_results_panel.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_availability_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/shared/layout/shell_layout.dart';
import 'package:novel_viewer/shared/providers/layout_providers.dart';

/// Width of the left column, in both shell layouts.
///
/// The narrow layout puts the same panel in a drawer of this width rather than
/// the material default, so the panel never lays out at a width the wide
/// layout does not also produce.
const double kLeftColumnWidth = 250;

/// Width of the right column, in both shell layouts.
const double kRightColumnWidth = 300;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Action for `SwitchPaneIntent` (Tab). Disabled while a text field is focused
/// so Tab keeps its normal behavior during text entry (e.g. the search box)
/// instead of switching panes.
class _SwitchPaneAction extends Action<SwitchPaneIntent> {
  _SwitchPaneAction(this.onToggle);

  final VoidCallback onToggle;

  @override
  bool isEnabled(SwitchPaneIntent intent) => !isTextInputFocused();

  @override
  Object? invoke(SwitchPaneIntent intent) {
    onToggle();
    return null;
  }
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Focus scopes for the two panes that `switchPane` (Tab) cycles between.
  /// The debug labels are also used by widget tests to assert which pane holds
  /// focus.
  final FocusScopeNode _fileBrowserPaneFocus = FocusScopeNode(
    debugLabel: 'fileBrowserPane',
  );
  final FocusScopeNode _novelPaneFocus = FocusScopeNode(
    debugLabel: 'novelPane',
  );

  /// Lets the narrow layout drive its drawers from provider state.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// The layout the last build produced, so a crossing of the breakpoint can
  /// be told apart from an ordinary rebuild.
  ShellLayout? _lastLayout;

  /// Whether the download dialog is on screen. A request that arrives while it
  /// is open is handled by the dialog itself, which knows whether it is in a
  /// state to take another URL; opening a second one over it would only stack
  /// two dialogs.
  bool _downloadDialogOpen = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalEscape);
    // Start with the file browser focused so the user can immediately navigate
    // files. A post-frame request wins over the descendant viewer's autofocus.
    //
    // In the narrow layout that pane is inside a closed drawer and its scope is
    // not in the tree, so there is nothing to focus; asking anyway happens to
    // be ignored, but only because an unattached node has no focus manager to
    // ask. MediaQuery is unavailable in initState and available here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final layout = resolveShellLayout(
        width: MediaQuery.sizeOf(context).width,
        breakpoint: ref.read(shellBreakpointProvider),
      );
      if (layout == ShellLayout.narrow) return;
      _fileBrowserPaneFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalEscape);
    _fileBrowserPaneFocus.dispose();
    _novelPaneFocus.dispose();
    super.dispose();
  }

  /// Escape as a context-dependent cancel key. When a real text input is focused
  /// (e.g. the search box), Escape is left to that field — it closes search.
  /// Otherwise Escape closes an active search first (this covers a selection
  /// search, which shows results but no editable field to receive Escape), and
  /// only stops TTS when no search is open.
  bool _handleGlobalEscape(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;

    // A genuine text field handles its own Escape. Read-only SelectableText
    // (focused novel body) is not a text field, so Escape still works there.
    if (isTextInputFocused()) return false;

    final searchActive =
        ref.read(searchBoxVisibleProvider) ||
        ref.read(searchQueryProvider) != null;
    if (searchActive) {
      closeSearchSession(ref);
      return true;
    }

    final playback = ref.read(ttsPlaybackStateProvider);
    if (playback == TtsPlaybackState.playing ||
        playback == TtsPlaybackState.paused ||
        playback == TtsPlaybackState.waiting) {
      ref.read(ttsStopRequestProvider.notifier).request();
      return true;
    }
    return false;
  }

  /// Opens or closes the end drawer to match the right column's visibility.
  ///
  /// `rightColumnVisibleProvider` stays the single source of truth in both
  /// layouts: the shortcut, the selection search and Escape all go on setting
  /// it, and the drawer follows. Without this the narrow layout would carry a
  /// second, competing notion of whether the search results are showing.
  void _syncEndDrawer(bool visible) {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold == null || !scaffold.hasEndDrawer) return;
    if (visible && !scaffold.isEndDrawerOpen) {
      scaffold.openEndDrawer();
    } else if (!visible && scaffold.isEndDrawerOpen) {
      scaffold.closeEndDrawer();
    }
  }

  /// Closes the left drawer once the reader has picked something from it.
  ///
  /// The drawer covers the text it was used to choose, so leaving it open
  /// would make every selection take a second dismissal. Listening to the
  /// selection rather than passing a callback into the panel means the
  /// bookmark tab — and any later tab — closes it too, without any of them
  /// knowing they are inside a drawer.
  void _closeDrawerIfOpen() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold == null || !scaffold.isDrawerOpen) return;
    scaffold.closeDrawer();
  }

  /// Opens the download dialog, optionally with a URL already in it, and
  /// remembers that it is up for as long as it stays there.
  Future<void> _openDownloadDialog({Uri? initialUrl}) async {
    _downloadDialogOpen = true;
    try {
      await DownloadDialog.show(context, initialUrl: initialUrl);
    } finally {
      _downloadDialogOpen = false;
    }
  }

  /// Ends the search session when the reader dismisses the drawer themselves —
  /// a tap on the scrim, a back gesture.
  ///
  /// The whole session goes, not just the column's visibility: the search box
  /// and the query are what `_onSearchShortcut` looks at to decide whether a
  /// press opens or closes. Clearing only the visibility would leave the
  /// session "active" with nothing on screen, so the next press would take the
  /// closing branch and appear to do nothing — on the one entry point a tablet
  /// without a keyboard has.
  ///
  /// Note this fires only for a dismissal, not when the drawer is torn down
  /// with the narrow layout; a rotation therefore keeps the search open, and
  /// the wide layout shows it as the right column.
  void _onEndDrawerChanged(bool isOpened) {
    if (isOpened) return;
    if (!ref.read(rightColumnVisibleProvider)) return;
    closeSearchSession(ref);
  }

  /// Toggles focus between the file browser and novel panes (Tab).
  void _switchPane() {
    if (_fileBrowserPaneFocus.hasFocus) {
      _novelPaneFocus.requestFocus();
    } else {
      _fileBrowserPaneFocus.requestFocus();
    }
  }

  /// Ctrl/Cmd+F behavior. A text selection that differs from the active query
  /// runs an immediate search on that selection. Otherwise the shortcut toggles
  /// the search session: open it (and the right column) when nothing is active,
  /// or close the whole session (including the right column) when one is active.
  ///
  /// Comparing the selection to the current query (rather than just "is there a
  /// selection") is what lets a second Ctrl+F close a selection-search while the
  /// same text is still highlighted, instead of re-searching it forever.
  void _onSearchShortcut() {
    // Only the text matters here; the selection's offset is for TTS.
    final selectedText = ref.read(selectedTextProvider)?.text;
    final query = ref.read(searchQueryProvider);

    if (selectedText != null &&
        selectedText.isNotEmpty &&
        selectedText != query) {
      ref.read(selectedSearchMatchProvider.notifier).clear();
      ref.read(searchQueryProvider.notifier).setQuery(selectedText);
      if (!ref.read(rightColumnVisibleProvider)) {
        ref.read(rightColumnVisibleProvider.notifier).toggle();
      }
      return;
    }

    final isActive = ref.read(searchBoxVisibleProvider) || query != null;
    if (isActive) {
      closeSearchSession(ref);
    } else {
      ref.read(searchBoxVisibleProvider.notifier).show();
      if (!ref.read(rightColumnVisibleProvider)) {
        ref.read(rightColumnVisibleProvider.notifier).toggle();
      }
    }
  }

  /// Prompts for a name and creates an empty `web` collection that articles can
  /// be added to later from the download dialog.
  Future<void> _showCreateCollectionDialog() async {
    final libraryPath = ref.read(libraryPathProvider);
    if (libraryPath == null) return;
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.download_createCollectionTitle),
        content: TextField(
          key: const Key('create_collection_name_field'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.download_createCollectionHint,
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.common_cancelButton),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.download_createCollectionButton),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty) return;
    await ref
        .read(downloadProvider.notifier)
        .createEmptyCollection(name: name, libraryPath: libraryPath);
    ref.invalidate(directoryContentsProvider);
  }

  Widget _buildBookmarkButton() {
    final folderPath = ref.watch(currentNovelFolderPathProvider).value;
    final selectedFile = ref.watch(selectedFileProvider);
    final isEnabled = folderPath != null && selectedFile != null;
    final isBookmarked = ref.watch(isBookmarkedProvider);

    return IconButton(
      key: const Key('bookmark_button'),
      icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
      onPressed: isEnabled ? () => _toggleBookmark() : null,
      tooltip: isBookmarked
          ? AppLocalizations.of(context)!.homeScreen_removeBookmarkTooltip
          : AppLocalizations.of(context)!.homeScreen_addBookmarkTooltip,
    );
  }

  Future<void> _toggleBookmark() async {
    final folderPath = await ref.read(currentNovelFolderPathProvider.future);
    final selectedFile = ref.read(selectedFileProvider);
    if (folderPath == null || selectedFile == null) return;

    final lineNumber = ref.read(currentViewLineProvider);
    final isBookmarked = ref.read(isBookmarkedProvider);
    final repository = await ref.read(
      bookmarkRepositoryProvider(folderPath).future,
    );

    await toggleBookmark(
      repository,
      fileName: selectedFile.name,
      isCurrentlyBookmarked: isBookmarked,
      lineNumber: lineNumber,
    );

    ref.invalidate(isBookmarkedProvider);
    ref.invalidate(bookmarksForCurrentNovelProvider);
    ref.invalidate(bookmarkLineNumbersForFileProvider);
  }

  @override
  Widget build(BuildContext context) {
    // The only place the display width is read to choose a shell shape. The
    // resolved layout is passed down; no other widget consults MediaQuery for
    // it.
    final layout = resolveShellLayout(
      width: MediaQuery.sizeOf(context).width,
      breakpoint: ref.watch(shellBreakpointProvider),
    );
    final isNarrow = layout == ShellLayout.narrow;
    ref.listen(rightColumnVisibleProvider, (_, visible) {
      _syncEndDrawer(visible);
    });
    // The act of opening a file closes the drawer, not a change of which file
    // is open: tapping the episode already being read hands back the cached
    // FileEntry and would notify nobody. Entering a folder only clears the
    // selection — the reader is still choosing — and does not count.
    ref.listen(fileOpenRequestProvider, (_, _) {
      _closeDrawerIfOpen();
    });
    // A download asked for from outside the app — a shared link, a shortcut —
    // reaches the reader as a pre-filled dialog awaiting confirmation, never as
    // a download that simply starts.
    ref.listen(pendingDownloadRequestProvider, (_, next) {
      if (next == null || _downloadDialogOpen) return;
      ref.read(pendingDownloadRequestProvider.notifier).markHandled(next);
      _openDownloadDialog(initialUrl: next.url);
    });
    // Crossing the breakpoint replaces the end drawer without any change to
    // the provider, so nothing above would open a drawer for a search that was
    // already showing — and the scaffold hands its remembered "was open" flag
    // to the replacement, which can resurrect a search the reader has since
    // closed. Reconcile once, whenever the narrow layout is entered.
    if (_lastLayout != layout) {
      _lastLayout = layout;
      if (isNarrow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncEndDrawer(ref.read(rightColumnVisibleProvider));
        });
      }
    }
    final bindings = ref.watch(keyBindingsProvider);
    // Where TTS is unavailable the controls bar that listens for the toggle
    // request is never mounted, so registering the binding would consume the
    // key press and do nothing — for a row the reader cannot see or rebind.
    final ttsSupported = ref.watch(ttsSupportedProvider);
    // Dynamic Shortcuts map built from the customizable bindings. Only actions
    // with a wired Actions handler below are included; switchPane (Tab) and
    // ttsToggle (Ctrl+T) are added with their handlers in their own groups.
    final shortcuts = <ShortcutActivator, Intent>{
      for (final action in [
        ShortcutAction.search,
        ShortcutAction.bookmark,
        // The narrow layout keeps the file browser pane in a closed drawer,
        // so a registered binding would swallow Tab and move focus nowhere.
        // Unregistered, it falls through to normal focus traversal.
        if (!isNarrow) ShortcutAction.switchPane,
        if (ttsSupported) ShortcutAction.ttsToggle,
      ])
        if (bindings[action] != null)
          bindings[action]!.toActivator(): intentFor(action),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (_) {
              _onSearchShortcut();
              return null;
            },
          ),
          BookmarkIntent: CallbackAction<BookmarkIntent>(
            onInvoke: (_) {
              _toggleBookmark();
              return null;
            },
          ),
          SwitchPaneIntent: _SwitchPaneAction(_switchPane),
          TtsToggleIntent: CallbackAction<TtsToggleIntent>(
            onInvoke: (_) {
              ref.read(ttsToggleRequestProvider.notifier).request();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            key: _scaffoldKey,
            // The vertical viewer already reads a horizontal drag as a page
            // turn (see _tryDecideGestureMode in vertical_text_page.dart), so
            // leaving the edge-drag gestures on would take page turning away
            // at exactly the edges of the screen. The app bar's buttons are
            // the only way to open either drawer.
            drawerEnableOpenDragGesture: false,
            endDrawerEnableOpenDragGesture: false,
            // A drawer is laid out at the origin at the full height of the
            // scaffold, so it reaches behind the status bar and the home
            // indicator; the inset handling the app bar gives the body does
            // not reach it. The SafeArea sits inside the drawer rather than
            // in the panel because the panels are shared with the wide
            // layout, where they need no inset of their own, and because the
            // drawer's own surface should keep covering the inset area.
            drawer: isNarrow
                ? const Drawer(
                    width: kLeftColumnWidth,
                    child: SafeArea(
                      child: LeftColumnPanel(key: Key('left_column')),
                    ),
                  )
                : null,
            endDrawer: isNarrow
                ? const Drawer(
                    width: kRightColumnWidth,
                    child: SafeArea(
                      child: SearchResultsPanel(key: Key('right_column')),
                    ),
                  )
                : null,
            onEndDrawerChanged: _onEndDrawerChanged,
            appBar: AppBar(
              title: Text(
                ref.watch(selectedFileProgressTitleProvider),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // AppBar buttons are excluded from keyboard focus traversal so
              // Tab only cycles between the file browser and novel panes. They
              // remain fully usable via mouse.
              actions: [
                ExcludeFocus(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const UpdateBadge(),
                      _buildBookmarkButton(),
                      // In the narrow layout the right pane is the search
                      // results drawer, which the search button opens; a
                      // second button for the same drawer, labelled as showing
                      // a column, would describe a layout that is not there.
                      if (!isNarrow)
                        IconButton(
                          key: const Key('toggle_right_column_button'),
                          icon: Icon(
                            ref.watch(rightColumnVisibleProvider)
                                ? Icons.vertical_split
                                : Icons.view_sidebar,
                          ),
                          onPressed: () => ref
                              .read(rightColumnVisibleProvider.notifier)
                              .toggle(),
                          tooltip: ref.watch(rightColumnVisibleProvider)
                              ? AppLocalizations.of(
                                  context,
                                )!.homeScreen_hideRightColumnTooltip
                              : AppLocalizations.of(
                                  context,
                                )!.homeScreen_showRightColumnTooltip,
                        ),
                      IconButton(
                        key: const Key('new_collection_button'),
                        icon: const Icon(Icons.create_new_folder_outlined),
                        onPressed: _showCreateCollectionDialog,
                        tooltip: AppLocalizations.of(
                          context,
                        )!.fileBrowser_newCollection,
                      ),
                      // Always present: a tablet without a keyboard has no
                      // Ctrl/Cmd+F, so the shortcut cannot be the only way to
                      // reach search.
                      IconButton(
                        key: const Key('search_button'),
                        icon: const Icon(Icons.search),
                        onPressed: _onSearchShortcut,
                        tooltip: AppLocalizations.of(
                          context,
                        )!.homeScreen_searchTooltip,
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: _openDownloadDialog,
                        tooltip: AppLocalizations.of(
                          context,
                        )!.homeScreen_downloadTooltip,
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => SettingsDialog.show(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            body: HoverPopupHost(
              child: isNarrow
                  ? FocusScope(
                      node: _novelPaneFocus,
                      child: const TextViewerPanel(key: Key('center_column')),
                    )
                  : Row(
                      children: [
                        SizedBox(
                          width: kLeftColumnWidth,
                          child: FocusScope(
                            node: _fileBrowserPaneFocus,
                            child: const LeftColumnPanel(
                              key: Key('left_column'),
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: FocusScope(
                            node: _novelPaneFocus,
                            child: const TextViewerPanel(
                              key: Key('center_column'),
                            ),
                          ),
                        ),
                        if (ref.watch(rightColumnVisibleProvider)) ...[
                          const VerticalDivider(width: 1),
                          const SizedBox(
                            width: kRightColumnWidth,
                            child: SearchResultsPanel(key: Key('right_column')),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
