import 'package:flutter/material.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Builds the AdaptiveTextSelectionToolbar shown when the user opens the
/// horizontal text viewer's selection menu. The base items (Copy etc.) come
/// from Flutter's EditableTextState; this helper appends a dictionary-add
/// action and two LLM-analysis triggers when there is a non-empty selection.
Widget buildDictionaryContextMenu(
  BuildContext context,
  EditableTextState editableTextState, {
  required void Function(String selectedText) onAddToDictionary,
  void Function(String selectedText, SummaryType type)? onAnalyze,
}) {
  final l10n = AppLocalizations.of(context)!;
  final value = editableTextState.textEditingValue;
  final selection = value.selection;
  String selectedText = '';
  if (selection.isValid && !selection.isCollapsed) {
    final start = selection.start.clamp(0, value.text.length);
    final end = selection.end.clamp(0, value.text.length);
    if (start < end) {
      selectedText = value.text.substring(start, end);
    }
  }
  final buttonItems = buildAnalysisButtonItems(
    baseItems: editableTextState.contextMenuButtonItems,
    selectedText: selectedText,
    addToDictionaryLabel: l10n.contextMenu_addToDictionary,
    analyzeNoSpoilerLabel: l10n.contextMenu_analyzeNoSpoiler,
    analyzeSpoilerLabel: l10n.contextMenu_analyzeSpoiler,
    onAddToDictionary: onAddToDictionary,
    onAnalyze: onAnalyze,
  );
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: buttonItems,
  );
}

/// Pure helper for assembling the selection-toolbar button list. Extracted so
/// it can be unit-tested without an [EditableTextState]: callers pass the
/// already-extracted selected text and the localized "add to dictionary"
/// label, and receive the final button list ready for
/// [AdaptiveTextSelectionToolbar.buttonItems].
///
/// When [selectedText] is empty (no selection / collapsed selection), only
/// [baseItems] are returned. Otherwise the order is: base items, then
/// "add to dictionary", then "解析開始(ネタバレなし)", then
/// "解析開始(ネタバレあり)".
List<ContextMenuButtonItem> buildAnalysisButtonItems({
  required List<ContextMenuButtonItem> baseItems,
  required String selectedText,
  required String addToDictionaryLabel,
  String analyzeNoSpoilerLabel = '解析開始(ネタバレなし)',
  String analyzeSpoilerLabel = '解析開始(ネタバレあり)',
  required void Function(String selectedText) onAddToDictionary,
  void Function(String selectedText, SummaryType type)? onAnalyze,
}) {
  final items = [...baseItems];
  if (selectedText.isEmpty) return items;

  items.add(ContextMenuButtonItem(
    label: addToDictionaryLabel,
    onPressed: () {
      ContextMenuController.removeAny();
      onAddToDictionary(selectedText);
    },
  ));
  if (onAnalyze != null) {
    items.add(ContextMenuButtonItem(
      label: analyzeNoSpoilerLabel,
      onPressed: () {
        ContextMenuController.removeAny();
        onAnalyze(selectedText, SummaryType.noSpoiler);
      },
    ));
    items.add(ContextMenuButtonItem(
      label: analyzeSpoilerLabel,
      onPressed: () {
        ContextMenuController.removeAny();
        onAnalyze(selectedText, SummaryType.spoiler);
      },
    ));
  }
  return items;
}
