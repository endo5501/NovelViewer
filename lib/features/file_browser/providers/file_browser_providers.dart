import 'dart:io' show File;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:path/path.dart' as p;

final fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return FileSystemService();
});

class CurrentDirectoryNotifier extends Notifier<String?> {
  final String? _initialPath;

  CurrentDirectoryNotifier([this._initialPath]);

  @override
  String? build() => _initialPath;

  void setDirectory(String path) => state = path;
}

final currentDirectoryProvider =
    NotifierProvider<CurrentDirectoryNotifier, String?>(
        CurrentDirectoryNotifier.new);

final libraryPathProvider = Provider<String?>((ref) {
  throw UnimplementedError('libraryPathProvider must be overridden at startup');
});

final directoryContentsProvider =
    FutureProvider<DirectoryContents>((ref) async {
  final dirPath = ref.watch(currentDirectoryProvider);
  if (dirPath == null) {
    return DirectoryContents.empty();
  }

  final service = ref.watch(fileSystemServiceProvider);
  final files = await service.listTextFiles(dirPath);
  final sortedFiles = service.sortByNumericPrefix(files);
  var subdirectories = await service.listSubdirectories(dirPath);

  final libraryPath = ref.watch(libraryPathProvider);
  final isLibraryRoot = libraryPath != null && dirPath == libraryPath;

  if (isLibraryRoot) {
    final novels = await ref.watch(allNovelsProvider.future);
    final folderToTitle = {
      for (final novel in novels) novel.folderName: novel.title,
    };

    subdirectories = subdirectories
        .map((dir) => DirectoryEntry(
              name: dir.name,
              path: dir.path,
              displayName: folderToTitle[dir.name],
            ))
        .toList();
  }

  // Query TTS statuses if tts_audio.db exists in current directory
  var ttsStatuses = const <String, TtsEpisodeStatus>{};
  final ttsDbPath = p.join(dirPath, 'tts_audio.db');
  if (await File(ttsDbPath).exists()) {
    final ttsDb = TtsAudioDatabase(dirPath);
    try {
      final repo = TtsAudioRepository(ttsDb);
      ttsStatuses = await repo.getAllEpisodeStatuses();
    } catch (_) {
      // DB read failure should not break file listing
      ttsStatuses = const {};
    } finally {
      await ttsDb.close();
    }
  }

  return DirectoryContents(
    files: sortedFiles,
    subdirectories: subdirectories,
    ttsStatuses: ttsStatuses,
  );
});

final selectedNovelTitleProvider = FutureProvider<String?>((ref) async {
  final currentDir = ref.watch(currentDirectoryProvider);
  final libraryPath = ref.watch(libraryPathProvider);

  if (currentDir == null || libraryPath == null) return null;
  if (p.equals(currentDir, libraryPath)) return null;
  if (!p.isWithin(libraryPath, currentDir)) return null;

  final relativePath = p.relative(currentDir, from: libraryPath);
  final folderName = p.split(relativePath).first;

  final novels = await ref.watch(allNovelsProvider.future);
  final titleByFolder = {
    for (final novel in novels) novel.folderName: novel.title,
  };

  return titleByFolder[folderName] ?? folderName;
});

class SelectedFileNotifier extends Notifier<FileEntry?> {
  @override
  FileEntry? build() => null;

  void selectFile(FileEntry file) => state = file;
  void clear() => state = null;
}

final selectedFileProvider =
    NotifierProvider<SelectedFileNotifier, FileEntry?>(
        SelectedFileNotifier.new);

class DirectoryContents {
  final List<FileEntry> files;
  final List<DirectoryEntry> subdirectories;
  final Map<String, TtsEpisodeStatus> ttsStatuses;

  const DirectoryContents({
    required this.files,
    required this.subdirectories,
    this.ttsStatuses = const {},
  });

  factory DirectoryContents.empty() =>
      const DirectoryContents(files: [], subdirectories: []);

  bool get isEmpty => files.isEmpty && subdirectories.isEmpty;
}
