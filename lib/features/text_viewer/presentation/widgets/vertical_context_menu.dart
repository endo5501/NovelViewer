import 'package:flutter/material.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';

/// Actions surfaced in the vertical-mode selection context menu. Vertical
/// mode cannot use the horizontal [AdaptiveTextSelectionToolbar] flow because
/// [VerticalTextViewer] is a custom painter without an [EditableTextState];
/// the menu is constructed manually via [showMenu] instead.
enum VerticalContextAction {
  copy,
  addToDictionary,
  analyzeNoSpoiler,
  analyzeSpoiler,
}

/// Builds the four PopupMenuEntry items shown when the user opens the
/// vertical-mode context menu against a non-empty selection. Extracted as a
/// pure function so it can be unit-tested without showing a real menu.
List<PopupMenuEntry<VerticalContextAction>> buildVerticalContextMenuItems({
  required String copyLabel,
  required String addToDictionaryLabel,
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
    const PopupMenuItem(
      value: VerticalContextAction.analyzeNoSpoiler,
      child: Text('解析開始(ネタバレなし)'),
    ),
    const PopupMenuItem(
      value: VerticalContextAction.analyzeSpoiler,
      child: Text('解析開始(ネタバレあり)'),
    ),
  ];
}

/// Routes a chosen [VerticalContextAction] to the appropriate callback.
/// Pure dispatcher; keeps the call site declarative.
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
