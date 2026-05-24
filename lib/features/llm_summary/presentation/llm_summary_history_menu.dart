import 'package:flutter/material.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';

/// Actions surfaced in the right-click context menu of a history entry.
enum HistoryContextAction { copyNoSpoiler, copySpoiler, delete }

/// Builds the PopupMenuEntry list for a single history entry's context menu.
/// Copy items are conditional on the entry's [type] so the user never sees
/// a copy option for a row that does not exist.
List<PopupMenuEntry<HistoryContextAction>> buildHistoryContextMenuItems({
  required HistoryEntryType type,
  required String deleteLabel,
  required String copyNoSpoilerLabel,
  required String copySpoilerLabel,
}) {
  final items = <PopupMenuEntry<HistoryContextAction>>[];
  final hasNoSpoiler = type == HistoryEntryType.noSpoilerOnly ||
      type == HistoryEntryType.both;
  final hasSpoiler =
      type == HistoryEntryType.spoilerOnly || type == HistoryEntryType.both;

  if (hasNoSpoiler) {
    items.add(PopupMenuItem(
      value: HistoryContextAction.copyNoSpoiler,
      child: Text(copyNoSpoilerLabel),
    ));
  }
  if (hasSpoiler) {
    items.add(PopupMenuItem(
      value: HistoryContextAction.copySpoiler,
      child: Text(copySpoilerLabel),
    ));
  }
  items.add(PopupMenuItem(
    value: HistoryContextAction.delete,
    child: Text(deleteLabel, style: const TextStyle(color: Colors.red)),
  ));
  return items;
}

/// Routes a chosen [HistoryContextAction] to the appropriate callback. Copy
/// actions are silently skipped if the corresponding summary text is null,
/// guarding against a stale menu item firing after underlying data has
/// changed.
void dispatchHistoryContextAction(
  HistoryContextAction action, {
  required String? noSpoilerSummary,
  required String? spoilerSummary,
  required void Function(String text) onCopy,
  required void Function() onDelete,
}) {
  switch (action) {
    case HistoryContextAction.copyNoSpoiler:
      if (noSpoilerSummary != null) onCopy(noSpoilerSummary);
    case HistoryContextAction.copySpoiler:
      if (spoilerSummary != null) onCopy(spoilerSummary);
    case HistoryContextAction.delete:
      onDelete();
  }
}
