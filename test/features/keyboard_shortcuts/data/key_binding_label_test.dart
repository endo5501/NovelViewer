import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/key_binding_label.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';

void main() {
  test('formats Control+F as "Ctrl+F" on non-macOS', () {
    final b = KeyBinding(keyId: LogicalKeyboardKey.keyF.keyId, control: true);
    expect(formatKeyBinding(b), 'Ctrl+F');
  });

  test('formats Meta+F as "Cmd+F"', () {
    final b = KeyBinding(keyId: LogicalKeyboardKey.keyF.keyId, meta: true);
    expect(formatKeyBinding(b), 'Cmd+F');
  });

  test('formats a bare Tab as "Tab"', () {
    final b = KeyBinding(keyId: LogicalKeyboardKey.tab.keyId);
    expect(formatKeyBinding(b), 'Tab');
  });

  test('orders modifiers and includes shift', () {
    final b = KeyBinding(
      keyId: LogicalKeyboardKey.keyG.keyId,
      control: true,
      shift: true,
    );
    expect(formatKeyBinding(b), 'Ctrl+Shift+G');
  });
}
