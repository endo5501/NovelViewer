import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/text_download/data/novel_library_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final libraryService = NovelLibraryService();
  final libraryDir = await libraryService.ensureLibraryDirectory();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        currentDirectoryProvider
            .overrideWith(() => CurrentDirectoryNotifier(libraryDir.path)),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const NovelViewerApp(),
    ),
  );
}
