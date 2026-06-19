import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/app/selected_file_progress_title_provider.dart';
import 'package:novel_viewer/features/app_update/presentation/update_badge.dart';
import 'package:novel_viewer/features/bookmark/presentation/left_column_panel.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_intents.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_host.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_search/presentation/search_results_panel.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/shared/providers/layout_providers.dart';

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
  bool isEnabled(SwitchPaneIntent intent) {
    final ctx = FocusManager.instance.primaryFocus?.context;
    return ctx == null ||
        ctx.findAncestorStateOfType<EditableTextState>() == null;
  }

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
  final FocusScopeNode _fileBrowserPaneFocus =
      FocusScopeNode(debugLabel: 'fileBrowserPane');
  final FocusScopeNode _novelPaneFocus =
      FocusScopeNode(debugLabel: 'novelPane');

  @override
  void initState() {
    super.initState();
    // Start with the file browser focused so the user can immediately navigate
    // files. A post-frame request wins over the descendant viewer's autofocus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fileBrowserPaneFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _fileBrowserPaneFocus.dispose();
    _novelPaneFocus.dispose();
    super.dispose();
  }

  /// Toggles focus between the file browser and novel panes (Tab).
  void _switchPane() {
    if (_fileBrowserPaneFocus.hasFocus) {
      _novelPaneFocus.requestFocus();
    } else {
      _fileBrowserPaneFocus.requestFocus();
    }
  }

  /// Ctrl/Cmd+F behavior. A current text selection always triggers an immediate
  /// search on that selection. Otherwise the shortcut toggles the search box:
  /// open it (and the right column) when no search is active, or close the whole
  /// search session (including the right column) when one is active.
  void _onSearchShortcut() {
    final selectedText = ref.read(selectedTextProvider);
    if (selectedText != null && selectedText.isNotEmpty) {
      ref.read(selectedSearchMatchProvider.notifier).clear();
      ref.read(searchQueryProvider.notifier).setQuery(selectedText);
      if (!ref.read(rightColumnVisibleProvider)) {
        ref.read(rightColumnVisibleProvider.notifier).toggle();
      }
      return;
    }

    final isActive = ref.read(searchBoxVisibleProvider) ||
        ref.read(searchQueryProvider) != null;
    if (isActive) {
      closeSearchSession(ref);
    } else {
      ref.read(searchBoxVisibleProvider.notifier).show();
      if (!ref.read(rightColumnVisibleProvider)) {
        ref.read(rightColumnVisibleProvider.notifier).toggle();
      }
    }
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
      tooltip: isBookmarked ? AppLocalizations.of(context)!.homeScreen_removeBookmarkTooltip : AppLocalizations.of(context)!.homeScreen_addBookmarkTooltip,
    );
  }

  Future<void> _toggleBookmark() async {
    final folderPath = await ref.read(currentNovelFolderPathProvider.future);
    final selectedFile = ref.read(selectedFileProvider);
    if (folderPath == null || selectedFile == null) return;

    final lineNumber = ref.read(currentViewLineProvider);
    final isBookmarked = ref.read(isBookmarkedProvider);
    final repository =
        await ref.read(bookmarkRepositoryProvider(folderPath).future);

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
    final bindings = ref.watch(keyBindingsProvider);
    // Dynamic Shortcuts map built from the customizable bindings. Only actions
    // with a wired Actions handler below are included; switchPane (Tab) and
    // ttsToggle (Ctrl+T) are added with their handlers in their own groups.
    final shortcuts = <ShortcutActivator, Intent>{
      for (final action in const [
        ShortcutAction.search,
        ShortcutAction.bookmark,
        ShortcutAction.switchPane,
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
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
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
                            ? AppLocalizations.of(context)!.homeScreen_hideRightColumnTooltip
                            : AppLocalizations.of(context)!.homeScreen_showRightColumnTooltip,
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => DownloadDialog.show(context),
                        tooltip: AppLocalizations.of(context)!.homeScreen_downloadTooltip,
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
              child: Row(
                children: [
                  SizedBox(
                    width: 250,
                    child: FocusScope(
                      node: _fileBrowserPaneFocus,
                      child: const LeftColumnPanel(key: Key('left_column')),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: FocusScope(
                      node: _novelPaneFocus,
                      child: const TextViewerPanel(key: Key('center_column')),
                    ),
                  ),
                  if (ref.watch(rightColumnVisibleProvider)) ...[
                    const VerticalDivider(width: 1),
                    const SizedBox(
                      width: 300,
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
