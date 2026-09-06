import 'package:flutter/material.dart';
import 'package:novel_viewer/features/llm_summary/presentation/analysis_runner.dart';

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

/// Builds the vertical-mode selection menu.
///
/// Copy is always offered; every other entry appears only when its label is
/// supplied. The caller withholds the dictionary label where speech synthesis
/// is unavailable and the analysis labels where LLM summary is, which keeps
/// this builder a pure function that knows nothing about platforms.
List<PopupMenuEntry<VerticalContextAction>> buildVerticalContextMenuItems({
  required String copyLabel,
  String? addToDictionaryLabel,
  String? analyzeNoSpoilerLabel,
  String? analyzeSpoilerLabel,
}) {
  return [
    PopupMenuItem(value: VerticalContextAction.copy, child: Text(copyLabel)),
    if (addToDictionaryLabel != null)
      PopupMenuItem(
        value: VerticalContextAction.addToDictionary,
        child: Text(addToDictionaryLabel),
      ),
    if (analyzeNoSpoilerLabel != null)
      PopupMenuItem(
        value: VerticalContextAction.analyzeNoSpoiler,
        child: Text(analyzeNoSpoilerLabel),
      ),
    if (analyzeSpoilerLabel != null)
      PopupMenuItem(
        value: VerticalContextAction.analyzeSpoiler,
        child: Text(analyzeSpoilerLabel),
      ),
  ];
}

/// Routes a chosen menu entry to its handler.
///
/// Every handler but [onCopy] is optional, and a withheld one makes its action
/// a no-op. The builder above already omits an entry whose label is absent, so
/// this is the second layer: an entry that somehow survives without its handler
/// must do nothing rather than reach the speech engine or an LLM server.
void dispatchVerticalContextAction(
  VerticalContextAction action, {
  required String selectedText,
  required void Function(String selectedText) onCopy,
  void Function(String selectedText)? onAddToDictionary,
  void Function(String selectedText, AnalysisScope scope)? onAnalyze,
}) {
  switch (action) {
    case VerticalContextAction.copy:
      onCopy(selectedText);
    case VerticalContextAction.addToDictionary:
      onAddToDictionary?.call(selectedText);
    case VerticalContextAction.analyzeNoSpoiler:
      onAnalyze?.call(selectedText, AnalysisScope.upToCurrent);
    case VerticalContextAction.analyzeSpoiler:
      onAnalyze?.call(selectedText, AnalysisScope.upToAll);
  }
}
