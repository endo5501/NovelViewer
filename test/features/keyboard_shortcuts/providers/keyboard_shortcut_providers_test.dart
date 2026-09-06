import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_availability_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  Future<ProviderContainer> makeContainer({bool ttsSupported = true}) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Pin defaults to non-macOS so assertions are platform-independent.
        shortcutDefaultsProvider.overrideWithValue(
          defaultShortcutBindings(isApplePlatform: false),
        ),
        ttsSupportedProvider.overrideWithValue(ttsSupported),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('shortcutDefaultsProvider follows the target platform', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    Future<Map<ShortcutAction, KeyBinding>> defaultsFor(
      TargetPlatform platform,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(shortcutDefaultsProvider);
    }

    test('iOS gets ⌘, the modifier an iPad keyboard offers', () async {
      final defaults = await defaultsFor(TargetPlatform.iOS);
      expect(
        defaults[ShortcutAction.search],
        KeyBinding(keyId: LogicalKeyboardKey.keyF.keyId, meta: true),
      );
    });

    test('macOS gets ⌘ as before', () async {
      final defaults = await defaultsFor(TargetPlatform.macOS);
      expect(
        defaults[ShortcutAction.search],
        KeyBinding(keyId: LogicalKeyboardKey.keyF.keyId, meta: true),
      );
    });

    test('Windows keeps Control', () async {
      final defaults = await defaultsFor(TargetPlatform.windows);
      expect(
        defaults[ShortcutAction.search],
        KeyBinding(keyId: LogicalKeyboardKey.keyF.keyId, control: true),
      );
    });
  });

  test('keyBindingsProvider exposes defaults initially', () async {
    final container = await makeContainer();
    final bindings = container.read(keyBindingsProvider);
    expect(bindings, defaultShortcutBindings(isApplePlatform: false));
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

  test('rebind rejects a combination already used by another action', () async {
    final container = await makeContainer();
    final notifier = container.read(keyBindingsProvider.notifier);
    // search default is Control+F on non-macOS; assigning it to bookmark
    // must be rejected.
    final searchBinding = container.read(
      keyBindingsProvider,
    )[ShortcutAction.search]!;

    final applied = await notifier.rebind(
      ShortcutAction.bookmark,
      searchBinding,
    );

    expect(applied, isFalse);
    // bookmark keeps its original default binding.
    expect(
      container.read(keyBindingsProvider)[ShortcutAction.bookmark],
      defaultShortcutBindings(isApplePlatform: false)[ShortcutAction.bookmark],
    );
  });

  test(
    'rebind allows reassigning an action to its own current binding',
    () async {
      final container = await makeContainer();
      final notifier = container.read(keyBindingsProvider.notifier);
      final current = container.read(
        keyBindingsProvider,
      )[ShortcutAction.search]!;

      final applied = await notifier.rebind(ShortcutAction.search, current);

      expect(applied, isTrue);
    },
  );

  test('resetToDefaults restores and persists defaults', () async {
    final container = await makeContainer();
    final notifier = container.read(keyBindingsProvider.notifier);
    await notifier.rebind(
      ShortcutAction.search,
      KeyBinding(keyId: LogicalKeyboardKey.keyG.keyId, control: true),
    );

    await notifier.resetToDefaults();

    expect(
      container.read(keyBindingsProvider),
      defaultShortcutBindings(isApplePlatform: false),
    );
  });

  // The TTS action keeps its binding in storage on a platform that cannot run
  // TTS, but its row is not shown — so a conflict against it is a dead end:
  // the user is told the key is taken and has no way to free it.
  test(
    'a binding held only by an unavailable action does not block a rebind',
    () async {
      final container = await makeContainer(ttsSupported: false);
      final notifier = container.read(keyBindingsProvider.notifier);
      final ttsBinding = container.read(
        keyBindingsProvider,
      )[ShortcutAction.ttsToggle]!;

      final applied = await notifier.rebind(ShortcutAction.search, ttsBinding);

      expect(applied, isTrue);
      expect(
        container.read(keyBindingsProvider)[ShortcutAction.search],
        ttsBinding,
      );
    },
  );

  test('an available action still blocks a rebind', () async {
    final container = await makeContainer(ttsSupported: false);
    final notifier = container.read(keyBindingsProvider.notifier);
    final bookmarkBinding = container.read(
      keyBindingsProvider,
    )[ShortcutAction.bookmark]!;

    final applied = await notifier.rebind(
      ShortcutAction.search,
      bookmarkBinding,
    );

    expect(applied, isFalse);
  });

  test('the TTS action still blocks a rebind where TTS is available', () async {
    final container = await makeContainer();
    final notifier = container.read(keyBindingsProvider.notifier);
    final ttsBinding = container.read(
      keyBindingsProvider,
    )[ShortcutAction.ttsToggle]!;

    final applied = await notifier.rebind(ShortcutAction.search, ttsBinding);

    expect(applied, isFalse);
  });
}
