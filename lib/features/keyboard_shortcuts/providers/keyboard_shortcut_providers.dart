import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_availability_provider.dart';

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
  ///
  /// An action the platform cannot run is not counted as a conflict. Its
  /// binding stays in storage but its row is not offered, so treating it as
  /// taken would tell the user a key is in use by something they cannot see
  /// and cannot rebind.
  Future<bool> rebind(ShortcutAction action, KeyBinding binding) async {
    final conflict = state.entries.any(
      (entry) =>
          entry.key != action &&
          entry.value == binding &&
          _isAvailable(entry.key),
    );
    if (conflict) return false;

    final updated = Map<ShortcutAction, KeyBinding>.from(state)
      ..[action] = binding;
    await ref.read(settingsRepositoryProvider).setShortcutBindings(updated);
    state = updated;
    return true;
  }

  /// Returns the action currently bound to [binding], or `null` if none. Useful
  /// for surfacing which action a rejected duplicate conflicts with. Skips
  /// actions the platform cannot run, for the same reason [rebind] does.
  ShortcutAction? actionFor(KeyBinding binding) {
    for (final entry in state.entries) {
      if (entry.value == binding && _isAvailable(entry.key)) return entry.key;
    }
    return null;
  }

  bool _isAvailable(ShortcutAction action) =>
      action != ShortcutAction.ttsToggle || ref.read(ttsSupportedProvider);

  Future<void> resetToDefaults() async {
    final defaults = ref.read(shortcutDefaultsProvider);
    final restored = Map<ShortcutAction, KeyBinding>.from(defaults);
    await ref.read(settingsRepositoryProvider).setShortcutBindings(restored);
    state = restored;
  }
}
