import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';

void main() {
  group('KeyBinding', () {
    test('value equality compares key and modifiers', () {
      const a = KeyBinding(keyId: 0x00000066, control: true); // f
      const b = KeyBinding(keyId: 0x00000066, control: true);
      const c = KeyBinding(keyId: 0x00000066, meta: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('converts to a SingleActivator that matches the modifiers', () {
      const binding = KeyBinding(keyId: 0x00000066, control: true, shift: true);
      final activator = binding.toActivator();
      expect(activator.trigger, LogicalKeyboardKey.keyF);
      expect(activator.control, isTrue);
      expect(activator.shift, isTrue);
      expect(activator.meta, isFalse);
    });

    test('round-trips through SingleActivator', () {
      const original = KeyBinding(keyId: 0x00000074, meta: true); // t
      expect(KeyBinding.fromActivator(original.toActivator()), original);
    });
  });

  group('defaultShortcutBindings', () {
    test('uses Control modifier on non-macOS', () {
      final b = defaultShortcutBindings(isMacOS: false);
      expect(b[ShortcutAction.search],
          KeyBinding(keyId: LogicalKeyboardKey.keyF.keyId, control: true));
      expect(b[ShortcutAction.ttsToggle],
          KeyBinding(keyId: LogicalKeyboardKey.keyT.keyId, control: true));
    });

    test('uses Meta modifier on macOS', () {
      final b = defaultShortcutBindings(isMacOS: true);
      expect(b[ShortcutAction.search],
          KeyBinding(keyId: LogicalKeyboardKey.keyF.keyId, meta: true));
    });

    test('switchPane defaults to bare Tab', () {
      final b = defaultShortcutBindings(isMacOS: false);
      expect(b[ShortcutAction.switchPane],
          KeyBinding(keyId: LogicalKeyboardKey.tab.keyId));
    });

    test('provides a binding for every customizable action', () {
      final b = defaultShortcutBindings(isMacOS: false);
      expect(b.keys.toSet(), ShortcutAction.values.toSet());
    });
  });

  group('ShortcutBindingCodec round-trip', () {
    test('encode then decode restores the same bindings', () {
      final original = defaultShortcutBindings(isMacOS: false);
      final decoded = ShortcutBindingCodec.decode(
        ShortcutBindingCodec.encode(original),
        defaults: defaultShortcutBindings(isMacOS: false),
      );
      expect(decoded, original);
    });

    test('preserves a custom non-default binding', () {
      final custom = Map<ShortcutAction, KeyBinding>.from(
        defaultShortcutBindings(isMacOS: false),
      );
      custom[ShortcutAction.search] = KeyBinding(
        keyId: LogicalKeyboardKey.keyG.keyId,
        control: true,
        shift: true,
      );
      final decoded = ShortcutBindingCodec.decode(
        ShortcutBindingCodec.encode(custom),
        defaults: defaultShortcutBindings(isMacOS: false),
      );
      expect(
        decoded[ShortcutAction.search],
        KeyBinding(
            keyId: LogicalKeyboardKey.keyG.keyId, control: true, shift: true),
      );
    });
  });

  group('ShortcutBindingCodec.decode fallbacks', () {
    test('null raw yields the provided defaults', () {
      final defaults = defaultShortcutBindings(isMacOS: false);
      expect(ShortcutBindingCodec.decode(null, defaults: defaults), defaults);
    });

    test('missing actions are filled from defaults', () {
      final defaults = defaultShortcutBindings(isMacOS: false);
      final partial = ShortcutBindingCodec.encode(
        {ShortcutAction.bookmark: defaults[ShortcutAction.bookmark]!},
      );
      final decoded = ShortcutBindingCodec.decode(partial, defaults: defaults);
      expect(decoded[ShortcutAction.search], defaults[ShortcutAction.search]);
      expect(
          decoded[ShortcutAction.bookmark], defaults[ShortcutAction.bookmark]);
      expect(decoded.keys.toSet(), ShortcutAction.values.toSet());
    });

    test('malformed JSON yields the provided defaults', () {
      final defaults = defaultShortcutBindings(isMacOS: false);
      expect(ShortcutBindingCodec.decode('not json {', defaults: defaults),
          defaults);
    });
  });
}
