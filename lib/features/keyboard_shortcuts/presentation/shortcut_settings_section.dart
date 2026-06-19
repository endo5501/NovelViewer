import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/key_binding_label.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Settings section that lists the customizable shortcut actions, shows the
/// current key for each, and lets the user rebind or reset them.
class ShortcutSettingsSection extends ConsumerWidget {
  const ShortcutSettingsSection({super.key});

  static String actionLabel(AppLocalizations l10n, ShortcutAction action) {
    switch (action) {
      case ShortcutAction.search:
        return l10n.shortcutAction_search;
      case ShortcutAction.bookmark:
        return l10n.shortcutAction_bookmark;
      case ShortcutAction.ttsToggle:
        return l10n.shortcutAction_ttsToggle;
      case ShortcutAction.switchPane:
        return l10n.shortcutAction_switchPane;
    }
  }

  Future<void> _reassign(
    BuildContext context,
    WidgetRef ref,
    ShortcutAction action,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final binding = await _captureKeyBinding(context);
    if (binding == null) return;

    final applied =
        await ref.read(keyBindingsProvider.notifier).rebind(action, binding);
    if (!applied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settings_shortcutDuplicate)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bindings = ref.watch(keyBindingsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settings_shortcutsSection,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final action in ShortcutAction.values)
            ListTile(
              key: Key('shortcut_row_${action.name}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(actionLabel(l10n, action)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bindings[action] != null
                        ? formatKeyBinding(bindings[action]!)
                        : '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: Key('shortcut_reassign_${action.name}'),
                    onPressed: () => _reassign(context, ref, action),
                    child: Text(l10n.settings_shortcutReassign),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('shortcut_reset_defaults'),
              onPressed: () =>
                  ref.read(keyBindingsProvider.notifier).resetToDefaults(),
              child: Text(l10n.settings_shortcutResetDefaults),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a small modal that captures the next key combination and returns it as
/// a [KeyBinding]. Returns null if dismissed without a non-modifier key.
Future<KeyBinding?> _captureKeyBinding(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<KeyBinding>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        content: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.handled;
            final key = event.logicalKey;
            if (_isModifierKey(key)) return KeyEventResult.handled;

            final pressed = HardwareKeyboard.instance.logicalKeysPressed;
            bool any(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
                pressed.contains(a) || pressed.contains(b);

            final binding = KeyBinding(
              keyId: key.keyId,
              control: any(LogicalKeyboardKey.controlLeft,
                  LogicalKeyboardKey.controlRight),
              meta: any(
                  LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight),
              shift: any(
                  LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight),
              alt: any(LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight),
            );
            Navigator.of(dialogContext).pop(binding);
            return KeyEventResult.handled;
          },
          child: Text(l10n.settings_shortcutPressKeys),
        ),
      );
    },
  );
}

bool _isModifierKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight;
}
