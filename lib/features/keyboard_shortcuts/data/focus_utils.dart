import 'package:flutter/widgets.dart';

/// Whether a *real* text input (an editable field) currently holds focus.
///
/// `SelectableText` is built on a read-only `EditableText`, so naively checking
/// for an `EditableTextState` ancestor would treat focused novel body text as a
/// text field. That would wrongly suppress global shortcuts (Tab pane-switch,
/// Escape-to-stop-TTS) whenever the reader has clicked into the text. Excluding
/// read-only editables keeps those shortcuts working while still deferring to
/// genuine inputs like the search box.
bool isTextInputFocused() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  final editable = ctx.findAncestorStateOfType<EditableTextState>();
  return editable != null && !editable.widget.readOnly;
}
