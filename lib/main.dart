import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/text_download/data/novel_library_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final libraryService = NovelLibraryService();
  final libraryDir = await libraryService.ensureLibraryDirectory();

  runApp(
    ProviderScope(
      overrides: [
        currentDirectoryProvider
            .overrideWith(() => CurrentDirectoryNotifier(libraryDir.path)),
      ],
      child: const NovelViewerApp(),
    ),
  );
}
