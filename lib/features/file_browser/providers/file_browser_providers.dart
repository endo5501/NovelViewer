import 'dart:io' show File;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode_status.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:path/path.dart' as p;

final _fileBrowserLog = Logger('file_browser');

final fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return FileSystemService();
});

class CurrentDirectoryNotifier extends Notifier<String?> {
  final String? _initialPath;

  CurrentDirectoryNotifier([this._initialPath]);

  @override
  String? build() => _initialPath;

  void setDirectory(String path) {
    final oldPath = state;
    state = path;
    if (oldPath != null && oldPath != path) {
      // Release the per-folder DB handles for the folder we just left.
      // The family providers are non-autoDispose by design, so this is the
      // explicit cleanup point on folder switch.
      ref.invalidate(ttsAudioDatabaseProvider(oldPath));
      ref.invalidate(ttsDictionaryDatabaseProvider(oldPath));
      ref.invalidate(episodeCacheDatabaseProvider(oldPath));
    }
  }
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

  // Map any subdirectory whose leaf name is a registered novel folder to its
  // database title, regardless of how deeply it is nested. Organizational
  // (unregistered) folders keep their folder name as-is. See
  // [isNovelFolder] for the discriminator.
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

  // Skip TTS lookup when no DB file is present so we don't materialize a
  // long-lived family entry for a folder that doesn't need one.
  var ttsStatuses = const <String, TtsEpisodeStatus>{};
  final ttsDbPath = p.join(dirPath, 'tts_audio.db');
  if (await File(ttsDbPath).exists()) {
    final ttsDb = ref.watch(ttsAudioDatabaseProvider(dirPath));
    try {
      final repo = TtsAudioRepository(ttsDb);
      ttsStatuses = await repo.getAllEpisodeStatuses();
    } catch (e, st) {
      _fileBrowserLog.warning(
          'Failed to read TTS statuses for $dirPath; '
          'falling back to no-status listing',
          e,
          st);
      ttsStatuses = const {};
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

  final relativeParts = p.split(p.relative(currentDir, from: libraryPath));

  final novels = await ref.watch(allNovelsProvider.future);
  final titleByFolder = {
    for (final novel in novels) novel.folderName: novel.title,
  };

  // Walk from the deepest path component upward and return the title of the
  // nearest ancestor that is a registered novel folder. This makes the lookup
  // independent of how deeply the novel is nested under organizational
  // folders. If no component is a registered novel, fall back to the first
  // component's folder name (legacy title-based / organizational folders).
  for (final part in relativeParts.reversed) {
    final title = titleByFolder[part];
    if (title != null) return title;
  }
  return relativeParts.first;
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
