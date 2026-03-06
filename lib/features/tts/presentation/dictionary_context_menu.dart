import 'package:flutter/material.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

Widget buildDictionaryContextMenu(
  BuildContext context,
  EditableTextState editableTextState, {
  required void Function(String selectedText) onAddToDictionary,
}) {
  final l10n = AppLocalizations.of(context)!;
  final buttonItems = editableTextState.contextMenuButtonItems;
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
  if (selectedText.isNotEmpty) {
    buttonItems.add(
      ContextMenuButtonItem(
        label: l10n.contextMenu_addToDictionary,
        onPressed: () {
          ContextMenuController.removeAny();
          onAddToDictionary(selectedText);
        },
      ),
    );
  }
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: buttonItems,
  );
}
