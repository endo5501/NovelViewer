import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_anchor.dart';
import 'package:novel_viewer/features/llm_summary/presentation/analysis_runner.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_detail_dialog.dart';
import 'package:novel_viewer/features/llm_summary/presentation/summary_snapshot_view.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Inline popup shown above a marked word when the pointer hovers it. Reads
/// all `word_summaries` snapshots for `(folder, word)`, chooses the default
/// one to display via [chooseDefaultSnapshot] (overridable via the snapshot
/// navigator), and renders the summary plus the snapshot label, the
/// re-analysis dropdown, and an optional future-snapshot warning icon.
class HoverPopupWidget extends ConsumerWidget {
  const HoverPopupWidget({
    super.key,
    required this.folderPath,
    required this.word,
    required this.currentEpisode,
    required this.currentFileName,
    required this.maxEpisodeInFolder,
    required this.maxEpisodeFileName,
  });

  /// Absolute path of the novel folder, used to resolve its per-folder
  /// `novel_data.db` snapshot cache.
  final String folderPath;
  final String word;

  /// Effective episode number of the file the user is currently viewing.
  /// Used both for the default snapshot selection rule and the future-snapshot
  /// warning. The `_runAnalysis` callbacks consume the matching file name.
  final int currentEpisode;
  final String? currentFileName;

  /// Effective episode number of the highest-prefix file in the folder, used
  /// by the "All chapters" re-analysis menu item. May equal [currentEpisode]
  /// for a single-file folder.
  final int maxEpisodeInFolder;
  final String? maxEpisodeFileName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotsAsync = ref.watch(
      hoverPopupCacheProvider((folderPath: folderPath, word: word)),
    );
    final activeEpisode = ref.watch(
      hoverPopupProvider.select((s) => s.activeEpisode),
    );
    final notifier = ref.read(hoverPopupProvider.notifier);

    final body = snapshotsAsync.when(
      loading: _LoadingCard.new,
      error: (_, _) => const SizedBox.shrink(),
      data: (snapshots) {
        if (snapshots.isEmpty) return const SizedBox.shrink();

        final displayed = _resolveDisplayedSnapshot(
          snapshots: snapshots,
          activeEpisode: activeEpisode,
          currentEpisode: currentEpisode,
        );
        if (displayed == null) return const SizedBox.shrink();

        return _Card(
          folderPath: folderPath,
          snapshots: snapshots,
          displayed: displayed,
          currentEpisode: currentEpisode,
          currentFileName: currentFileName,
          maxEpisodeInFolder: maxEpisodeInFolder,
          maxEpisodeFileName: maxEpisodeFileName,
          onSelectEpisode: notifier.setActiveEpisode,
        );
      },
    );

    return MouseRegion(
      onEnter: (_) => notifier.onPopupEnter(),
      onExit: (_) => notifier.onPopupExit(),
      child: body,
    );
  }

  static WordSummary? _resolveDisplayedSnapshot({
    required List<WordSummary> snapshots,
    required int? activeEpisode,
    required int currentEpisode,
  }) {
    if (activeEpisode != null) {
      for (final s in snapshots) {
        if (s.coveredUpToEpisode == activeEpisode) return s;
      }
    }
    return chooseDefaultSnapshot(snapshots, currentEpisode);
  }
}

class _Card extends ConsumerWidget {
  const _Card({
    required this.folderPath,
    required this.snapshots,
    required this.displayed,
    required this.currentEpisode,
    required this.currentFileName,
    required this.maxEpisodeInFolder,
    required this.maxEpisodeFileName,
    required this.onSelectEpisode,
  });

  final String folderPath;
  final List<WordSummary> snapshots;
  final WordSummary displayed;
  final int currentEpisode;
  final String? currentFileName;
  final int maxEpisodeInFolder;
  final String? maxEpisodeFileName;
  final ValueChanged<int?> onSelectEpisode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final showWarning = displayed.coveredUpToEpisode > currentEpisode;
    return Material(
      key: const Key('hover_popup_card'),
      elevation: 4,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kHoverPopupApproxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SummarySnapshotView(
                snapshots: snapshots,
                displayed: displayed,
                onSelectEpisode: onSelectEpisode,
                keyPrefix: 'hover_popup',
                showWarning: showWarning,
                // Reading a stored summary stays available everywhere — a
                // folder carried over from a desktop install keeps its
                // analysis readable. Starting a new one does not: this popup
                // is reachable on an iPad whenever a trackpad is attached,
                // since iPadOS delivers hover events then.
                trailing: ref.watch(llmSummarySupportedProvider)
                    ? _ReanalyzeMenuButton(
                        word: displayed.word,
                        snapshots: snapshots,
                        currentEpisode: currentEpisode,
                        currentFileName: currentFileName,
                        maxEpisodeInFolder: maxEpisodeInFolder,
                        maxEpisodeFileName: maxEpisodeFileName,
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              // A row of their own rather than beside re-analyze: the header
              // shares its width with the snapshot label, which on a touch
              // layout would have to be cut short to make room.
              //
              // Neither needs the LLM — one reads stored data, the other
              // removes it — so they stay where analysis cannot run. There
              // the popup is the only way to remove an analysis, since the
              // history tab is absent.
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DetailsButton(folderPath: folderPath, word: displayed.word),
                  _DeleteButton(folderPath: folderPath, word: displayed.word),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper exposed for tests: whether the re-analysis menu should append the
/// `(上書き)` suffix to a candidate `coveredUpToEpisode`.
bool shouldAppendOverwriteSuffix(
  List<WordSummary> snapshots,
  int candidateEpisode,
) {
  for (final s in snapshots) {
    if (s.coveredUpToEpisode == candidateEpisode) return true;
  }
  return false;
}

class _ReanalyzeMenuButton extends ConsumerStatefulWidget {
  const _ReanalyzeMenuButton({
    required this.word,
    required this.snapshots,
    required this.currentEpisode,
    required this.currentFileName,
    required this.maxEpisodeInFolder,
    required this.maxEpisodeFileName,
  });

  final String word;
  final List<WordSummary> snapshots;
  final int currentEpisode;
  final String? currentFileName;
  final int maxEpisodeInFolder;
  final String? maxEpisodeFileName;

  @override
  ConsumerState<_ReanalyzeMenuButton> createState() =>
      _ReanalyzeMenuButtonState();
}

class _ReanalyzeMenuButtonState extends ConsumerState<_ReanalyzeMenuButton> {
  // MenuController in Material is a plain controller (no ChangeNotifier,
  // no dispose method) — it just exposes open()/close() that delegate to
  // the bound MenuAnchor. No explicit cleanup is needed when the State
  // unmounts; the MenuAnchor unsubscribes itself.
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final overwriteSuffix = l10n.hoverPopup_reanalyzeOverwriteSuffix;

    String labelUpToCurrent = l10n.hoverPopup_reanalyzeUpToCurrent(
      widget.currentEpisode,
    );
    if (shouldAppendOverwriteSuffix(widget.snapshots, widget.currentEpisode)) {
      labelUpToCurrent += overwriteSuffix;
    }

    String labelUpToAll = l10n.hoverPopup_reanalyzeUpToAll(
      widget.maxEpisodeInFolder,
    );
    if (shouldAppendOverwriteSuffix(
      widget.snapshots,
      widget.maxEpisodeInFolder,
    )) {
      labelUpToAll += overwriteSuffix;
    }

    // Capture everything the analysis trigger needs WHILE this State is still
    // mounted. `MenuItemButton` defers its `onPressed` to a post-frame
    // callback *after* it closes the menu — and closing the menu hides the
    // popup and unmounts this State (its overlay entry is removed by the
    // host). By the time the callback runs, `context`, `ref`, and `widget`
    // are all defunct, so reading any of them throws and the analysis silently
    // never starts. `rootContext` (the root navigator) survives the teardown,
    // and `runner` is a plain object captured here while `ref` is valid.
    final runner = ref.read(analysisRunnerProvider);
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final word = widget.word;
    final currentEpisode = widget.currentEpisode;
    final currentFileName = widget.currentFileName;
    final maxEpisode = widget.maxEpisodeInFolder;
    final maxFileName = widget.maxEpisodeFileName;
    void runAnalysis(int episode, String? sourceFile) {
      runner.run(
        context: rootContext,
        word: word,
        coveredUpToEpisode: episode,
        sourceFileName: sourceFile,
      );
    }

    // Simple analysis goes through the scope entry point instead: the episode
    // it covers is the word's first occurrence, which is only known after
    // searching the folder. Resolving it here would make merely opening this
    // menu read every text file in the novel.
    void runSimpleAnalysis() {
      runner.runWithScope(
        context: rootContext,
        word: word,
        scope: AnalysisScope.firstOccurrence,
      );
    }

    return MenuAnchor(
      controller: _menuController,
      // Notify the hover-popup notifier when the menu opens / closes so the
      // popup's grace-period hide is suppressed while the pointer travels
      // from the popup body onto a menu item. Without this, leaving the
      // popup's MouseRegion to reach the dropdown would dismiss the popup
      // mid-travel and the menu items become unreachable.
      onOpen: () {
        if (!mounted) return;
        ref.read(hoverPopupProvider.notifier).onChildMenuOpen();
      },
      onClose: () {
        if (!mounted) return;
        ref.read(hoverPopupProvider.notifier).onChildMenuClose();
      },
      menuChildren: [
        // No episode hint and no overwrite suffix on this one: both would need
        // the folder searched to know which episode it lands on, and the mode
        // exists precisely for the reader who does not care which.
        MenuItemButton(
          key: const Key('hover_popup_reanalyze_simple'),
          onPressed: runSimpleAnalysis,
          child: Text(l10n.hoverPopup_reanalyzeSimple),
        ),
        MenuItemButton(
          key: const Key('hover_popup_reanalyze_up_to_current'),
          onPressed: () => runAnalysis(currentEpisode, currentFileName),
          child: Text(labelUpToCurrent),
        ),
        MenuItemButton(
          key: const Key('hover_popup_reanalyze_up_to_all'),
          onPressed: () => runAnalysis(maxEpisode, maxFileName),
          child: Text(labelUpToAll),
        ),
      ],
      builder: (context, controller, _) => TextButton.icon(
        key: const Key('hover_popup_reanalyze_button'),
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        icon: const Icon(Icons.refresh, size: 16),
        label: Text(
          l10n.hoverPopup_reanalyzeButton,
          style: const TextStyle(fontSize: 12),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          minimumSize: const Size(0, 24),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// Labelled action styled like the re-analyze button beside the navigator.
class _PopupActionButton extends StatelessWidget {
  const _PopupActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: const Size(0, 24),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Opens the same read-only word detail dialog the history menu opens.
class _DetailsButton extends StatelessWidget {
  const _DetailsButton({required this.folderPath, required this.word});

  final String folderPath;
  final String word;

  @override
  Widget build(BuildContext context) {
    return _PopupActionButton(
      key: const Key('hover_popup_details_button'),
      icon: Icons.info_outline,
      label: AppLocalizations.of(context)!.hoverPopup_detailsButton,
      // The dialog covers the popup, which then goes away and takes this
      // context with it — so it is shown from the root navigator instead.
      onPressed: () => showDialog<void>(
        context: Navigator.of(context, rootNavigator: true).context,
        builder: (_) =>
            LlmSummaryDetailDialog(folderPath: folderPath, word: word),
      ),
    );
  }
}

/// Deletes the word's analysis — every snapshot and its facts, as the history
/// menu's delete does — after a confirmation. The history menu deletes without
/// one; a control inside a transient popup over the text is easier to press by
/// mistake than a context-menu item.
class _DeleteButton extends ConsumerWidget {
  const _DeleteButton({required this.folderPath, required this.word});

  final String folderPath;
  final String word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PopupActionButton(
      key: const Key('hover_popup_delete_button'),
      icon: Icons.delete_outline,
      label: AppLocalizations.of(context)!.hoverPopup_deleteButton,
      onPressed: () => _confirmAndDelete(context, ref),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    // Everything the deletion needs is taken now, while this widget is still
    // mounted. The dialog covers the popup, the pointer leaves it, and the
    // host removes it — by the time the dialog returns, `context` and `ref`
    // are defunct. Same constraint as the re-analyze menu.
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final history = ref.read(llmSummaryHistoryProvider.notifier);
    final popup = ref.read(hoverPopupProvider.notifier);
    final folderPath = this.folderPath;
    final word = this.word;

    final confirmed = await showDialog<bool>(
      context: rootContext,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(l10n.hoverPopup_deleteConfirmTitle(word)),
          content: Text(l10n.hoverPopup_deleteConfirmMessage),
          actions: [
            TextButton(
              key: const Key('hover_popup_delete_cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.common_cancelButton),
            ),
            TextButton(
              key: const Key('hover_popup_delete_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.bookmark_deleteMenuItem),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    // A touch-opened popup is still up under the dialog — no pointer left it.
    // Once its word is gone it has nothing left to show.
    popup.hide();
    await history.deleteEntry(word, novelFolder: folderPath);
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('hover_popup_card'),
      elevation: 4,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          key: Key('hover_popup_loading'),
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
