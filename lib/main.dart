import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/app/startup_migrations.dart';
import 'package:novel_viewer/shared/logging/app_logger.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/text_download/data/novel_library_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLogger.initialize();

  if (Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized();
  }

  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final libraryService = NovelLibraryService();
  await libraryService.migrateFromOldBundleId();
  final libraryDir = await libraryService.ensureLibraryDirectory();
  final prefs = await SharedPreferences.getInstance();
  await runStartupMigrations(SettingsRepository(prefs));
  // Wire a real folder lister so the v4→v5 LLM summary migration can resolve
  // lexical ranks for legacy rows whose source_file lacks a numeric prefix.
  final novelDatabase = NovelDatabase(
    snapshotResolver:
        NovelDatabaseSnapshotResolver.fromLibraryRoot(libraryDir.path),
  );
  await novelDatabase.database;

  final packageInfo = await PackageInfo.fromPlatform();

  final container = ProviderContainer(
    overrides: [
      currentDirectoryProvider
          .overrideWith(() => CurrentDirectoryNotifier(libraryDir.path)),
      libraryPathProvider.overrideWithValue(libraryDir.path),
      sharedPreferencesProvider.overrideWithValue(prefs),
      novelDatabaseProvider.overrideWithValue(novelDatabase),
      packageInfoProvider.overrideWithValue(packageInfo),
    ],
  );

  // Fire-and-forget background update check; never blocks first paint.
  unawaited(container.read(updateStatusProvider.notifier).check());

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NovelViewerApp(),
    ),
  );
}
