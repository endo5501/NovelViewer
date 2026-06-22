import 'package:flutter/material.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Actions surfaced in the right-click menu of a history-panel entry.
/// `copySnapshot` carries the episode number so the dispatch handler knows
/// which snapshot's summary to write to the clipboard.
sealed class HistoryContextAction {
  const HistoryContextAction();
}

class CopySnapshotAction extends HistoryContextAction {
  final int episode;
  const CopySnapshotAction(this.episode);
}

class DeleteEntryAction extends HistoryContextAction {
  const DeleteEntryAction();
}

/// Opens the read-only detail dialog for the entry's word, showing its cached
/// facts (`fact_cache`) and analysis-result snapshots (`word_summaries`).
class ViewDetailsAction extends HistoryContextAction {
  const ViewDetailsAction();
}

/// Caps the number of copy submenu entries to avoid an unreadably tall
/// menu when (improbably) more than 8 snapshots exist. Picks the 8 most
/// recently updated and returns them sorted ascending by episode for display.
List<WordSummary> pickTopSnapshotsForCopyMenu(
  List<WordSummary> snapshots, {
  int max = 8,
}) {
  if (snapshots.length <= max) {
    final sorted = [...snapshots]
      ..sort((a, b) => a.coveredUpToEpisode.compareTo(b.coveredUpToEpisode));
    return sorted;
  }
  final byRecency = [...snapshots]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final picked = byRecency.take(max).toList()
    ..sort((a, b) => a.coveredUpToEpisode.compareTo(b.coveredUpToEpisode));
  return picked;
}

/// Builds the items for the history entry context menu. The copy submenu is
/// expanded inline as nested `PopupMenuItem` rows because `showMenu` does
/// not natively support nested popups.
List<PopupMenuEntry<HistoryContextAction>> buildHistoryContextMenuItems({
  required HistoryEntry entry,
  required AppLocalizations l10n,
}) {
  final items = <PopupMenuEntry<HistoryContextAction>>[];
  final snapshots = pickTopSnapshotsForCopyMenu(entry.snapshots);
  for (final s in snapshots) {
    items.add(PopupMenuItem(
      value: CopySnapshotAction(s.coveredUpToEpisode),
      child: Text(
        l10n.contextMenu_copySnapshotByEpisode(s.coveredUpToEpisode),
      ),
    ));
  }
  if (items.isNotEmpty) {
    items.add(const PopupMenuDivider());
  }
  items.add(PopupMenuItem(
    value: const ViewDetailsAction(),
    child: Text(l10n.contextMenu_viewDetails),
  ));
  items.add(PopupMenuItem(
    value: const DeleteEntryAction(),
    child: Text(
      l10n.bookmark_deleteMenuItem,
      style: const TextStyle(color: Colors.red),
    ),
  ));
  return items;
}

/// Resolve the user's menu choice into the right side-effect.
void dispatchHistoryContextAction(
  HistoryContextAction action, {
  required HistoryEntry entry,
  required void Function(String text) onCopy,
  required void Function() onDelete,
  required void Function() onViewDetails,
}) {
  switch (action) {
    case CopySnapshotAction(:final episode):
      for (final s in entry.snapshots) {
        if (s.coveredUpToEpisode == episode) {
          onCopy(s.summary);
          return;
        }
      }
    case DeleteEntryAction():
      onDelete();
    case ViewDetailsAction():
      onViewDetails();
  }
}
