import 'package:flutter/material.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

/// Actions surfaced in the vertical-mode selection context menu. The vertical
/// viewer is a custom painter without an [EditableTextState], so the menu is
/// constructed manually via [showMenu] rather than the
/// [AdaptiveTextSelectionToolbar] flow used in horizontal mode.
enum VerticalContextAction {
  copy,
  addToDictionary,
  analyzeNoSpoiler,
  analyzeSpoiler,
}

List<PopupMenuEntry<VerticalContextAction>> buildVerticalContextMenuItems({
  required String copyLabel,
  required String addToDictionaryLabel,
  required String analyzeNoSpoilerLabel,
  required String analyzeSpoilerLabel,
}) {
  return [
    PopupMenuItem(
      value: VerticalContextAction.copy,
      child: Text(copyLabel),
    ),
    PopupMenuItem(
      value: VerticalContextAction.addToDictionary,
      child: Text(addToDictionaryLabel),
    ),
    PopupMenuItem(
      value: VerticalContextAction.analyzeNoSpoiler,
      child: Text(analyzeNoSpoilerLabel),
    ),
    PopupMenuItem(
      value: VerticalContextAction.analyzeSpoiler,
      child: Text(analyzeSpoilerLabel),
    ),
  ];
}

void dispatchVerticalContextAction(
  VerticalContextAction action, {
  required String selectedText,
  required void Function(String selectedText) onCopy,
  required void Function(String selectedText) onAddToDictionary,
  required void Function(String selectedText, SummaryType type) onAnalyze,
}) {
  switch (action) {
    case VerticalContextAction.copy:
      onCopy(selectedText);
    case VerticalContextAction.addToDictionary:
      onAddToDictionary(selectedText);
    case VerticalContextAction.analyzeNoSpoiler:
      onAnalyze(selectedText, SummaryType.noSpoiler);
    case VerticalContextAction.analyzeSpoiler:
      onAnalyze(selectedText, SummaryType.spoiler);
  }
}
