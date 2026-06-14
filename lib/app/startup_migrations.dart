import 'package:logging/logging.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';

final _log = Logger('startup');

/// Run one-shot data migrations that must complete before the application
/// reaches `runApp`. Each migration is wrapped so a single failure cannot
/// block startup; failures are recorded via the AppLogger pipeline (WARNING)
/// so they remain traceable in release builds.
Future<void> runStartupMigrations(SettingsRepository repo) async {
  try {
    await repo.migrateApiKeyToSecureStorage();
  } catch (e, stack) {
    _log.warning('runStartupMigrations: API key migration failed: $e', e, stack);
  }
}
