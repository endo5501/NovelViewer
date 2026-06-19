import 'package:flutter/services.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';

/// Human-readable label for a [KeyBinding], e.g. `Ctrl+Shift+G`, `Cmd+F`, `Tab`.
///
/// Modifiers are listed in a stable order (Ctrl, Cmd, Alt, Shift) followed by
/// the trigger key. Used by the shortcut settings UI.
String formatKeyBinding(KeyBinding binding) {
  final parts = <String>[];
  if (binding.control) parts.add('Ctrl');
  if (binding.meta) parts.add('Cmd');
  if (binding.alt) parts.add('Alt');
  if (binding.shift) parts.add('Shift');
  parts.add(_keyLabel(LogicalKeyboardKey(binding.keyId)));
  return parts.join('+');
}

String _keyLabel(LogicalKeyboardKey key) {
  if (key.keyLabel.isNotEmpty) return key.keyLabel;
  // Non-printable keys (Tab, arrows, etc.) have an empty keyLabel; fall back to
  // the debug name, which reads well enough for the settings list.
  return key.debugName ?? 'Key ${key.keyId}';
}
