import 'package:flutter/foundation.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';

/// Run one-shot data migrations that must complete before the application
/// reaches `runApp`. Each migration is wrapped so a single failure cannot
/// block startup; failures are surfaced via [debugPrint] only.
Future<void> runStartupMigrations(SettingsRepository repo) async {
  try {
    await repo.migrateApiKeyToSecureStorage();
  } catch (e, stack) {
    debugPrint('runStartupMigrations: API key migration failed: $e\n$stack');
  }
}
