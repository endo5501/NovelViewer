import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/app/startup_migrations.dart';
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
    repo = SettingsRepository(prefs, secureStorage: const FlutterSecureStorage());
  });

  tearDown(() {
    secureStorageMock.uninstall();
  });

  test(
      'runStartupMigrations transfers a legacy SharedPreferences API key into '
      'secure storage on first run', () async {
    await prefs.setString('llm_api_key', 'sk-legacy');

    await runStartupMigrations(repo);

    expect(secureStorageMock.store['llm_api_key'], 'sk-legacy');
    expect(prefs.containsKey('llm_api_key'), isFalse);
  });

  test(
      'runStartupMigrations swallows exceptions so app startup is never '
      'blocked', () async {
    await prefs.setString('llm_api_key', 'sk-legacy');
    secureStorageMock.forceWriteFailure = true;

    // Capture debugPrint output so the failure path is verifiable without
    // leaking onto the test console.
    final logs = <String?>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message);
    addTearDown(() => debugPrint = previous);

    await expectLater(runStartupMigrations(repo), completes);

    expect(prefs.getString('llm_api_key'), 'sk-legacy');
  });

  test('runStartupMigrations is a no-op for a fresh install', () async {
    await runStartupMigrations(repo);

    expect(secureStorageMock.store, isEmpty);
    expect(prefs.containsKey('llm_api_key'), isFalse);
  });
}
