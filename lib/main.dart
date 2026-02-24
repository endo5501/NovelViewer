import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/text_download/data/novel_library_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  final novelDatabase = NovelDatabase();
  await novelDatabase.database;

  runApp(
    ProviderScope(
      overrides: [
        currentDirectoryProvider
            .overrideWith(() => CurrentDirectoryNotifier(libraryDir.path)),
        libraryPathProvider.overrideWithValue(libraryDir.path),
        sharedPreferencesProvider.overrideWithValue(prefs),
        novelDatabaseProvider.overrideWithValue(novelDatabase),
      ],
      child: const NovelViewerApp(),
    ),
  );
}
