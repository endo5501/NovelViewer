import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

/// Platform-aware default bindings. Overridable in tests to pin the modifier
/// (Control vs Meta) regardless of the host platform.
final shortcutDefaultsProvider = Provider<Map<ShortcutAction, KeyBinding>>(
  (ref) => defaultShortcutBindings(
    isMacOS: defaultTargetPlatform == TargetPlatform.macOS,
  ),
);

/// Current keyboard shortcut bindings for the customizable actions.
final keyBindingsProvider =
    NotifierProvider<KeyBindingsNotifier, Map<ShortcutAction, KeyBinding>>(
  KeyBindingsNotifier.new,
);

class KeyBindingsNotifier extends Notifier<Map<ShortcutAction, KeyBinding>> {
  @override
  Map<ShortcutAction, KeyBinding> build() {
    final repository = ref.watch(settingsRepositoryProvider);
    final defaults = ref.watch(shortcutDefaultsProvider);
    return repository.getShortcutBindings(defaults: defaults);
  }

  /// Assigns [binding] to [action]. Rejects (returns `false`, no change) if the
  /// same combination is already bound to a *different* action, so the user
  /// never silently overwrites an existing assignment. Reassigning an action to
  /// its own current binding is allowed.
  Future<bool> rebind(ShortcutAction action, KeyBinding binding) async {
    final conflict = state.entries
        .any((entry) => entry.key != action && entry.value == binding);
    if (conflict) return false;

    final updated = Map<ShortcutAction, KeyBinding>.from(state)
      ..[action] = binding;
    await ref.read(settingsRepositoryProvider).setShortcutBindings(updated);
    state = updated;
    return true;
  }

  /// Returns the action currently bound to [binding], or `null` if none. Useful
  /// for surfacing which action a rejected duplicate conflicts with.
  ShortcutAction? actionFor(KeyBinding binding) {
    for (final entry in state.entries) {
      if (entry.value == binding) return entry.key;
    }
    return null;
  }

  Future<void> resetToDefaults() async {
    final defaults = ref.read(shortcutDefaultsProvider);
    final restored = Map<ShortcutAction, KeyBinding>.from(defaults);
    await ref.read(settingsRepositoryProvider).setShortcutBindings(restored);
    state = restored;
  }
}
