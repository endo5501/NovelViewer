import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';

/// A value-equatable key combination.
///
/// Flutter's [SingleActivator] uses identity equality, which makes it unsuitable
/// for duplicate detection and value comparison. [KeyBinding] holds the same
/// information (a trigger key id plus modifier flags) with proper `==`/`hashCode`
/// and converts to/from [SingleActivator] when wiring up `Shortcuts`.
@immutable
class KeyBinding {
  const KeyBinding({
    required this.keyId,
    this.control = false,
    this.meta = false,
    this.shift = false,
    this.alt = false,
  });

  final int keyId;
  final bool control;
  final bool meta;
  final bool shift;
  final bool alt;

  LogicalKeyboardKey get key => LogicalKeyboardKey(keyId);

  SingleActivator toActivator() => SingleActivator(
        LogicalKeyboardKey(keyId),
        control: control,
        meta: meta,
        shift: shift,
        alt: alt,
      );

  factory KeyBinding.fromActivator(SingleActivator a) => KeyBinding(
        keyId: a.trigger.keyId,
        control: a.control,
        meta: a.meta,
        shift: a.shift,
        alt: a.alt,
      );

  Map<String, dynamic> toJson() => {
        'key': keyId,
        'control': control,
        'meta': meta,
        'shift': shift,
        'alt': alt,
      };

  factory KeyBinding.fromJson(Map<String, dynamic> json) => KeyBinding(
        keyId: json['key'] as int,
        control: json['control'] as bool? ?? false,
        meta: json['meta'] as bool? ?? false,
        shift: json['shift'] as bool? ?? false,
        alt: json['alt'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is KeyBinding &&
      other.keyId == keyId &&
      other.control == control &&
      other.meta == meta &&
      other.shift == shift &&
      other.alt == alt;

  @override
  int get hashCode => Object.hash(keyId, control, meta, shift, alt);

  @override
  String toString() =>
      'KeyBinding(keyId: $keyId, control: $control, meta: $meta, '
      'shift: $shift, alt: $alt)';
}

/// Default key bindings for the customizable shortcut actions.
///
/// The primary command modifier is platform dependent: Meta (⌘) on macOS,
/// Control on every other desktop platform. `switchPane` uses a bare Tab.
Map<ShortcutAction, KeyBinding> defaultShortcutBindings({
  required bool isMacOS,
}) {
  KeyBinding cmd(LogicalKeyboardKey key) =>
      KeyBinding(keyId: key.keyId, control: !isMacOS, meta: isMacOS);

  return {
    ShortcutAction.search: cmd(LogicalKeyboardKey.keyF),
    ShortcutAction.bookmark: cmd(LogicalKeyboardKey.keyB),
    ShortcutAction.ttsToggle: cmd(LogicalKeyboardKey.keyT),
    ShortcutAction.switchPane: KeyBinding(keyId: LogicalKeyboardKey.tab.keyId),
  };
}

/// JSON (de)serialization for shortcut bindings persisted in SharedPreferences.
///
/// Decoding always starts from the supplied defaults, so missing, unknown, or
/// malformed entries fall back to the default binding rather than dropping the
/// action entirely.
class ShortcutBindingCodec {
  const ShortcutBindingCodec._();

  static String encode(Map<ShortcutAction, KeyBinding> bindings) {
    final map = <String, dynamic>{
      for (final entry in bindings.entries) entry.key.name: entry.value.toJson(),
    };
    return jsonEncode(map);
  }

  static Map<ShortcutAction, KeyBinding> decode(
    String? raw, {
    required Map<ShortcutAction, KeyBinding> defaults,
  }) {
    final result = Map<ShortcutAction, KeyBinding>.from(defaults);
    if (raw == null || raw.isEmpty) return result;

    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      return result;
    }
    if (parsed is! Map) return result;

    for (final action in ShortcutAction.values) {
      final entry = parsed[action.name];
      if (entry is Map) {
        try {
          result[action] = KeyBinding.fromJson(Map<String, dynamic>.from(entry));
        } catch (_) {
          // Keep the default for this action on a malformed entry.
        }
      }
    }
    return result;
  }
}
