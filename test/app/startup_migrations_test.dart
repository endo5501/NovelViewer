import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/app/startup_migrations.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_utils/flutter_secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FlutterSecureStorageMock secureStorageMock;
  late SettingsRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    secureStorageMock = FlutterSecureStorageMock();
    secureStorageMock.install();
    repo = SettingsRepository(
      prefs,
      secureStorage: const FlutterSecureStorage(),
    );
  });

  tearDown(() {
    secureStorageMock.uninstall();
  });

  test('runStartupMigrations transfers a legacy SharedPreferences API key into '
      'secure storage on first run', () async {
    await prefs.setString('llm_api_key', 'sk-legacy');

    await runStartupMigrations(repo);

    expect(secureStorageMock.store['llm_api_key'], 'sk-legacy');
    expect(prefs.containsKey('llm_api_key'), isFalse);
  });

  test('runStartupMigrations swallows exceptions so app startup is never '
      'blocked and records the failure via AppLogger', () async {
    await prefs.setString('llm_api_key', 'sk-legacy');
    secureStorageMock.forceWriteFailure = true;

    // The failure must reach the AppLogger pipeline (WARNING) rather than
    // debugPrint only, so it leaves a trace in release builds.
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);

    await expectLater(runStartupMigrations(repo), completes);

    expect(prefs.getString('llm_api_key'), 'sk-legacy');
    expect(records.any((r) => r.level == Level.WARNING), isTrue);
  });

  test('runStartupMigrations is a no-op for a fresh install', () async {
    await runStartupMigrations(repo);

    expect(secureStorageMock.store, isEmpty);
    expect(prefs.containsKey('llm_api_key'), isFalse);
  });

  group('retired shortcut bindings', () {
    // The stored map is keyed by the enum's own names, so an action that no
    // longer exists leaves an entry nothing can read or rebind.
    const storageKey = 'keyboard_shortcuts';

    Future<void> storeRaw(Map<String, Object?> bindings) =>
        prefs.setString(storageKey, jsonEncode(bindings));

    Map<String, dynamic> readRaw() =>
        jsonDecode(prefs.getString(storageKey)!) as Map<String, dynamic>;

    test('drops an entry for an action that no longer exists', () async {
      await storeRaw({
        'switchPane': KeyBinding(keyId: LogicalKeyboardKey.tab.keyId).toJson(),
        'search': KeyBinding(
          keyId: LogicalKeyboardKey.keyF.keyId,
          control: true,
        ).toJson(),
      });

      await runStartupMigrations(repo);

      expect(readRaw().containsKey('switchPane'), isFalse);
    });

    test('keeps the customizations of actions that still exist', () async {
      final custom = KeyBinding(
        keyId: LogicalKeyboardKey.keyG.keyId,
        control: true,
      );
      await storeRaw({
        'switchPane': KeyBinding(keyId: LogicalKeyboardKey.tab.keyId).toJson(),
        'search': custom.toJson(),
      });

      await runStartupMigrations(repo);

      final defaults = defaultShortcutBindings(isApplePlatform: false);
      expect(
        repo.getShortcutBindings(defaults: defaults)[ShortcutAction.search],
        custom,
      );
    });

    test('frees the key the retired action was holding', () async {
      // A reader who had moved the pane switch onto Ctrl+P must be able to
      // give Ctrl+P to something else afterwards.
      final freed = KeyBinding(
        keyId: LogicalKeyboardKey.keyP.keyId,
        control: true,
      );
      await storeRaw({'switchPane': freed.toJson()});

      await runStartupMigrations(repo);

      final defaults = defaultShortcutBindings(isApplePlatform: false);
      final bindings = repo.getShortcutBindings(defaults: defaults);
      expect(bindings.values, isNot(contains(freed)));
    });

    test('leaves a fresh install with nothing stored', () async {
      await runStartupMigrations(repo);

      expect(prefs.containsKey(storageKey), isFalse);
    });
  });
}
