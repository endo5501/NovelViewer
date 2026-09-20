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
import 'package:novel_viewer/features/novel_refresh/presentation/refresh_progress_dialog.dart';
import 'package:novel_viewer/features/novel_refresh/providers/refresh_target_provider.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
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

/// Width of the right column, where it is a column.
const double kRightColumnWidth = 300;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Action for `ToggleFileBrowserIntent` (Tab). Disabled while a text field is
/// focused so Tab keeps its normal behavior during text entry (e.g. the search
/// box) instead of opening the drawer.
class _ToggleFileBrowserAction extends Action<ToggleFileBrowserIntent> {
  _ToggleFileBrowserAction(this.onToggle);

  final VoidCallback onToggle;

  @override
  bool isEnabled(ToggleFileBrowserIntent intent) => !isTextInputFocused();

  @override
  Object? invoke(ToggleFileBrowserIntent intent) {
    onToggle();
    return null;
  }
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Focus scope for the text viewer. The debug label is also used by widget
  /// tests to assert where focus lands.
  final FocusScopeNode _novelPaneFocus = FocusScopeNode(
    debugLabel: 'novelPane',
  );

  /// Lets the shell drive its drawers directly: the search results follow
  /// provider state, and the file browser is opened at startup and toggled by
  /// its shortcut.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// The layout the last build produced, so a crossing of the breakpoint can
  /// be told apart from an ordinary rebuild.
  ShellLayout? _lastLayout;

  /// Whether the startup open has been dealt with, one way or another.
  ///
  /// Set when the drawer is opened for the launch, and also as soon as the
  /// reader touches the drawer themselves: on a large library the restoration
  /// can still be running then, and it must not throw the file browser back
  /// over whatever they have gone on to do.
  bool _startupDrawerSettled = false;

  /// Whether the download dialog is on screen. A request that arrives while it
  /// is open is handled by the dialog itself, which knows whether it is in a
  /// state to take another URL; opening a second one over it would only stack
  /// two dialogs.
  bool _downloadDialogOpen = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalEscape);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalEscape);
    _novelPaneFocus.dispose();
    super.dispose();
  }

  /// Escape as a context-dependent cancel key. When a real text input is focused
  /// (e.g. the search box), Escape is left to that field — it closes search.
  /// Otherwise Escape dismisses whatever is in front of the reader: the file
  /// browser drawer first, then an active search (this covers a selection
  /// search, which shows results but no editable field to receive Escape), and
  /// only stops TTS when neither is up.
  bool _handleGlobalEscape(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;

    // A genuine text field handles its own Escape. Read-only SelectableText
    // (focused novel body) is not a text field, so Escape still works there.
    if (isTextInputFocused()) return false;

    // The drawer is over everything else, so it goes first and alone; a second
    // press then reaches the search beneath it.
    //
    // Unless a dialog is over the drawer in turn — the file browser opens
    // several, to confirm a delete or pick a move target. Those dismiss
    // themselves through the focus tree, and returning true here would not
    // stop that: `KeyEventManager` dispatches the message to the focus tree
    // whatever a `HardwareKeyboard` handler returns. Taking the same press
    // for the drawer would close it under the dialog.
    //
    // The end drawer is deliberately not handled here. Dismissing it is itself
    // the end of the search session — `_onEndDrawerChanged` says so — and
    // closing it separately would end the search on the same press anyway,
    // which is exactly the one-press-one-layer promise this branch makes.
    final scaffold = _scaffoldKey.currentState;
    final nothingModalAbove = ModalRoute.of(context)?.isCurrent ?? true;
    if (nothingModalAbove && scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return true;
    }

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

  /// The app bar's download button, which means whichever of its two things
  /// the reader is in a position to want.
  ///
  /// Reading an episode of a novel that can be re-fetched, the useful download
  /// is that novel's own update — the reason to press it is that the site has
  /// gone on without them. Anywhere else there is nothing to update, so the
  /// button is what it always was: the way to fetch something new.
  ///
  /// The icon and the tooltip change together with the behavior, so the button
  /// never has to be pressed to find out which one it is. It is never disabled:
  /// each state has something to do.
  Widget _buildDownloadButton() {
    final l10n = AppLocalizations.of(context)!;
    final target = ref.watch(refreshTargetProvider);

    return IconButton(
      key: const Key('appbar_download_button'),
      icon: Icon(target == null ? Icons.download : Icons.sync),
      onPressed: target == null
          ? _openDownloadDialog
          : () => startNovelRefresh(context, ref, target),
      tooltip: target == null
          ? l10n.homeScreen_downloadTooltip
          : l10n.homeScreen_refreshNovelTooltip,
    );
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

  /// Opens the file browser once the last reading session has settled.
  ///
  /// The app starts by asking what to read, so the drawer is the first thing
  /// on screen. It waits for the restoration because that is what turns the
  /// listing from the library root into the episodes of the novel being read:
  /// opening first would show the reader that substitution happening.
  ///
  /// Settled covers all three endings — a novel restored, nothing to restore,
  /// or a failure — so there is no case where the drawer never opens.
  void _openStartupDrawer() {
    if (_startupDrawerSettled) return;
    _startupDrawerSettled = true;
    // This runs from a provider listener or from build, so the drawer cannot
    // be opened on the spot. `addPostFrameCallback` does not request a frame
    // of its own — its callback runs "after the next frame (whenever that may
    // be, if ever)" — and nothing here rebuilds anything, so the frame has to
    // be asked for. `ensureVisualUpdate` is the form that does nothing when a
    // frame is already under way, where the callback will run at its end.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scaffoldKey.currentState?.openDrawer();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Shows or hides the file browser (Tab).
  ///
  /// The drawer is the only place the file browser lives, at every display
  /// width, so this is the whole of "go and pick something else to read".
  void _toggleFileBrowser() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold == null) return;
    if (scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    } else {
      scaffold.openDrawer();
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
    final displayWidth = MediaQuery.sizeOf(context).width;
    final layout = resolveShellLayout(
      width: displayWidth,
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
    // A listener sees transitions only, and an empty library settles in a
    // microtask — soon enough to be done before this first build. Reading the
    // current value as well is what covers that case.
    ref.listen(readingProgressStartupProvider, (_, next) {
      if (next.isLoading) return;
      _openStartupDrawer();
    });
    if (!ref.read(readingProgressStartupProvider).isLoading) {
      _openStartupDrawer();
    }
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
    // with a wired Actions handler below are included; toggleFileBrowser (Tab)
    // and ttsToggle (Ctrl+T) are added with their handlers in their own groups.
    final shortcuts = <ShortcutActivator, Intent>{
      for (final action in [
        ShortcutAction.search,
        ShortcutAction.bookmark,
        // The file browser drawer exists at every display width, so its
        // binding is registered at every display width too.
        ShortcutAction.toggleFileBrowser,
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
          ToggleFileBrowserIntent: _ToggleFileBrowserAction(_toggleFileBrowser),
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
            // in the panel so the drawer's own surface keeps covering the
            // inset area.
            //
            // The file browser lives here at every display width: a reader
            // picks an episode and returns to the text, so a column standing
            // beside the text the whole time only narrowed it — and narrowed
            // the file names past legibility.
            drawer: Drawer(
              width: fileBrowserDrawerWidth(displayWidth: displayWidth),
              child: const SafeArea(
                child: LeftColumnPanel(key: Key('left_column')),
              ),
            ),
            endDrawer: isNarrow
                ? const Drawer(
                    width: kRightColumnWidth,
                    child: SafeArea(
                      child: SearchResultsPanel(key: Key('right_column')),
                    ),
                  )
                : null,
            // A drawer the reader opens or closes themselves means they have
            // taken over from the launch: a restoration settling afterwards
            // must not reopen what they just put away.
            onDrawerChanged: (_) => _startupDrawerSettled = true,
            onEndDrawerChanged: _onEndDrawerChanged,
            appBar: AppBar(
              title: Text(
                ref.watch(selectedFileProgressTitleProvider),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // AppBar buttons are excluded from keyboard focus traversal so
              // that Tab keeps reaching the file browser drawer rather than
              // walking along this row. They remain fully usable via mouse.
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
                      _buildDownloadButton(),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => SettingsDialog.show(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // One row in both layouts. With the file browser in the drawer
            // the only thing the layout decides is whether the search results
            // stand beside the text or come over it.
            body: HoverPopupHost(
              child: Row(
                children: [
                  Expanded(
                    child: FocusScope(
                      node: _novelPaneFocus,
                      child: const TextViewerPanel(key: Key('center_column')),
                    ),
                  ),
                  if (!isNarrow && ref.watch(rightColumnVisibleProvider)) ...[
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
