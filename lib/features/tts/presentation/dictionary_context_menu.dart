import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novel_viewer/features/llm_summary/presentation/analysis_runner.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// The horizontal-mode selection toolbar.
///
/// Each optional item is dropped by passing no callback for it: the dictionary
/// item where speech synthesis is unavailable (the dictionary exists only to
/// instruct the engine), the analysis items where LLM summary is unavailable.
Widget buildDictionaryContextMenu(
  BuildContext context,
  EditableTextState editableTextState, {
  required String selectedText,
  void Function(String selectedText)? onAddToDictionary,
  void Function(String selectedText, AnalysisScope scope)? onAnalyze,
}) {
  final l10n = AppLocalizations.of(context)!;
  final buttonItems = buildAnalysisButtonItems(
    baseItems: editableTextState.contextMenuButtonItems,
    selectedText: selectedText,
    addToDictionaryLabel: onAddToDictionary == null
        ? null
        : l10n.contextMenu_addToDictionary,
    analyzeNoSpoilerLabel: onAnalyze == null
        ? null
        : l10n.contextMenu_analyzeNoSpoiler,
    analyzeSpoilerLabel: onAnalyze == null
        ? null
        : l10n.contextMenu_analyzeSpoiler,
    onAddToDictionary: onAddToDictionary,
    onAnalyze: onAnalyze,
  );
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: buttonItems,
  );
}

/// Builds the item list for the horizontal-mode selection toolbar.
///
/// An optional group is included only when its label and its callback are both
/// supplied; omitting either drops it. This keeps the builder a pure function
/// with no knowledge of platforms or providers, so both outcomes are testable.
List<ContextMenuButtonItem> buildAnalysisButtonItems({
  required List<ContextMenuButtonItem> baseItems,
  required String selectedText,
  String? addToDictionaryLabel,
  String? analyzeNoSpoilerLabel,
  String? analyzeSpoilerLabel,
  void Function(String selectedText)? onAddToDictionary,
  void Function(String selectedText, AnalysisScope scope)? onAnalyze,
}) {
  assert(
    (addToDictionaryLabel == null) == (onAddToDictionary == null),
    'the dictionary item needs both a label and a callback, or neither',
  );
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

  if (addToDictionaryLabel != null && onAddToDictionary != null) {
    items.add(
      ContextMenuButtonItem(
        label: addToDictionaryLabel,
        onPressed: () {
          ContextMenuController.removeAny();
          onAddToDictionary(selectedText);
        },
      ),
    );
  }
  if (onAnalyze != null &&
      analyzeNoSpoilerLabel != null &&
      analyzeSpoilerLabel != null) {
    items.add(
      ContextMenuButtonItem(
        label: analyzeNoSpoilerLabel,
        onPressed: () {
          ContextMenuController.removeAny();
          onAnalyze(selectedText, AnalysisScope.upToCurrent);
        },
      ),
    );
    items.add(
      ContextMenuButtonItem(
        label: analyzeSpoilerLabel,
        onPressed: () {
          ContextMenuController.removeAny();
          onAnalyze(selectedText, AnalysisScope.upToAll);
        },
      ),
    );
  }
  return items;
}
