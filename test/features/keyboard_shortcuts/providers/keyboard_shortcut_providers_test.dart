import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Pin defaults to non-macOS so assertions are platform-independent.
      shortcutDefaultsProvider
          .overrideWithValue(defaultShortcutBindings(isMacOS: false)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('keyBindingsProvider exposes defaults initially', () async {
    final container = await makeContainer();
    final bindings = container.read(keyBindingsProvider);
    expect(bindings, defaultShortcutBindings(isMacOS: false));
  });

  test('rebind updates and persists the binding', () async {
    final container = await makeContainer();
    final notifier = container.read(keyBindingsProvider.notifier);

    final applied = await notifier.rebind(
      ShortcutAction.ttsToggle,
      KeyBinding(keyId: LogicalKeyboardKey.keyP.keyId, control: true),
    );

    expect(applied, isTrue);
    expect(
      container.read(keyBindingsProvider)[ShortcutAction.ttsToggle],
      KeyBinding(keyId: LogicalKeyboardKey.keyP.keyId, control: true),
    );
  });

  test('rebind rejects a combination already used by another action',
      () async {
    final container = await makeContainer();
    final notifier = container.read(keyBindingsProvider.notifier);
    // search default is Control+F on non-macOS; assigning it to bookmark
    // must be rejected.
    final searchBinding =
        container.read(keyBindingsProvider)[ShortcutAction.search]!;

    final applied = await notifier.rebind(ShortcutAction.bookmark, searchBinding);

    expect(applied, isFalse);
    // bookmark keeps its original default binding.
    expect(
      container.read(keyBindingsProvider)[ShortcutAction.bookmark],
      defaultShortcutBindings(isMacOS: false)[ShortcutAction.bookmark],
    );
  });

  test('rebind allows reassigning an action to its own current binding',
      () async {
    final container = await makeContainer();
    final notifier = container.read(keyBindingsProvider.notifier);
    final current =
        container.read(keyBindingsProvider)[ShortcutAction.search]!;

    final applied = await notifier.rebind(ShortcutAction.search, current);

    expect(applied, isTrue);
  });

  test('resetToDefaults restores and persists defaults', () async {
    final container = await makeContainer();
    final notifier = container.read(keyBindingsProvider.notifier);
    await notifier.rebind(
      ShortcutAction.search,
      KeyBinding(keyId: LogicalKeyboardKey.keyG.keyId, control: true),
    );

    await notifier.resetToDefaults();

    expect(container.read(keyBindingsProvider),
        defaultShortcutBindings(isMacOS: false));
  });
}
