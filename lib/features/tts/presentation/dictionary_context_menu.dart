import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

Widget buildDictionaryContextMenu(
  BuildContext context,
  EditableTextState editableTextState, {
  required String selectedText,
  required void Function(String selectedText) onAddToDictionary,
  void Function(String selectedText, SummaryType type)? onAnalyze,
}) {
  final l10n = AppLocalizations.of(context)!;
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

List<ContextMenuButtonItem> buildAnalysisButtonItems({
  required List<ContextMenuButtonItem> baseItems,
  required String selectedText,
  required String addToDictionaryLabel,
  required String analyzeNoSpoilerLabel,
  required String analyzeSpoilerLabel,
  required void Function(String selectedText) onAddToDictionary,
  void Function(String selectedText, SummaryType type)? onAnalyze,
}) {
  // For SelectableText.rich, the default Copy item's onPressed routes
  // through EditableText.copySelection -> value.text.textInside(...),
  // which substitutes U+FFFC for each ruby WidgetSpan. Replace it so the
  // explicit ruby-base-expanded selectedText reaches the clipboard.
  final items = selectedText.isEmpty
      ? [...baseItems]
      : baseItems.map((item) {
          if (item.type != ContextMenuButtonType.copy) return item;
          return ContextMenuButtonItem(
            type: ContextMenuButtonType.copy,
            label: item.label,
            onPressed: () {
              ContextMenuController.removeAny();
              Clipboard.setData(ClipboardData(text: selectedText));
            },
          );
        }).toList();
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
