import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  SettingsRepository buildRepo() => SettingsRepository(prefs);

  Map<ShortcutAction, KeyBinding> defaults() =>
      defaultShortcutBindings(isMacOS: false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('SettingsRepository - shortcut bindings', () {
    test('returns defaults when nothing stored', () {
      final repo = buildRepo();
      expect(repo.getShortcutBindings(defaults: defaults()), defaults());
    });

    test('persists and restores a customized binding', () async {
      final repo = buildRepo();
      final custom = Map<ShortcutAction, KeyBinding>.from(defaults());
      custom[ShortcutAction.ttsToggle] = KeyBinding(
        keyId: LogicalKeyboardKey.keyP.keyId,
        control: true,
      );

      await repo.setShortcutBindings(custom);

      expect(
        repo.getShortcutBindings(defaults: defaults())[ShortcutAction.ttsToggle],
        KeyBinding(keyId: LogicalKeyboardKey.keyP.keyId, control: true),
      );
    });

    test('fills missing actions from defaults', () async {
      final repo = buildRepo();
      await repo.setShortcutBindings(
        {ShortcutAction.search: defaults()[ShortcutAction.search]!},
      );

      final restored = repo.getShortcutBindings(defaults: defaults());
      expect(restored.keys.toSet(), ShortcutAction.values.toSet());
      expect(restored[ShortcutAction.bookmark],
          defaults()[ShortcutAction.bookmark]);
    });
  });
}
