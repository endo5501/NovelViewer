import 'dart:io' show File;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/domain/reading_progress_badge.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode_status.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';
import 'package:novel_viewer/shared/database/novel_data_database_provider.dart';
import 'package:novel_viewer/shared/database/per_folder_db_registry_provider.dart';
import 'package:novel_viewer/shared/utils/novel_id_resolver.dart';
import 'package:path/path.dart' as p;

final _fileBrowserLog = Logger('file_browser');
final _readingProgressLog = Logger('reading_progress');

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
      // Release the per-folder DB handles for the folder we just left. The
      // registry owns the handles; eviction here is the explicit cleanup point
      // on folder switch. A switch races no file-system operation, so a
      // background close is fine (unlike move/rename/delete, which await
      // closeAll). The registry normalizes the key, so a handle opened under
      // any path-separator spelling is reachable. See [folderDbKey].
      ref.read(perFolderDbRegistryProvider).releaseInBackground(oldPath);
      // The thin-view providers cache their resolved handle, so invalidate them
      // to drop references to the evicted handle and recompute on next read.
      final oldKey = folderDbKey(oldPath);
      ref.invalidate(ttsAudioDatabaseProvider(oldKey));
      ref.invalidate(ttsDictionaryDatabaseProvider(oldKey));
      ref.invalidate(episodeCacheDatabaseProvider(oldKey));
      ref.invalidate(novelDataDatabaseProvider(oldKey));
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
    final ttsDb = ref.watch(ttsAudioDatabaseProvider(folderDbKey(dirPath)));
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

/// Reading progress badges keyed by `folder_name`, for the file browser to
/// render per-novel progress on registered novel folder tiles.
///
/// Both numbers come from the global `novel_metadata.db` only: the denominator
/// is `novels.episode_count`, the numerator is derived from
/// `reading_progress.file_name`'s leading episode number (0 = unread). No
/// folder DB is opened and no filesystem walk is performed. Only registered
/// novels appear in the map; unregistered (manual) folders are absent.
///
/// A bulk-read failure degrades to "no progress" (every novel reads as unread)
/// and is logged at WARNING on `Logger('reading_progress')`, so the file
/// listing stays usable.
final readingProgressBadgesProvider =
    FutureProvider<Map<String, ReadingProgressBadge>>((ref) async {
  final novels = await ref.watch(allNovelsProvider.future);
  // Recompute after any reading-progress write so a parent folder's badge
  // refreshes once the user advances inside the novel (the auto-save listener
  // bumps this revision after each successful upsert).
  ref.watch(readingProgressRevisionProvider);

  // NOTE: despite its name, `reading_progress.novel_id` stores the registered
  // novel's `folder_name` — the auto-save path keys rows by `resolveNovelId`,
  // which returns the nearest registered folder's leaf name (= folder_name),
  // NOT the site-specific `NovelMetadata.novelId`. So this map is keyed by
  // folder_name and the lookup below correctly uses `novel.folderName`.
  var fileNameByFolderName = const <String, String>{};
  try {
    final progress =
        await ref.watch(readingProgressRepositoryProvider).findAll();
    fileNameByFolderName = {for (final p in progress) p.novelId: p.fileName};
  } catch (e, st) {
    _readingProgressLog.warning(
      'Failed to bulk-read reading progress for file browser badges; '
      'falling back to unread for all novels',
      e,
      st,
    );
  }

  return {
    for (final novel in novels)
      novel.folderName: ReadingProgressBadge.from(
        episodeCount: novel.episodeCount,
        fileName: fileNameByFolderName[novel.folderName],
      ),
  };
});

final selectedNovelTitleProvider = FutureProvider<String?>((ref) async {
  final currentDir = ref.watch(currentDirectoryProvider);
  final libraryPath = ref.watch(libraryPathProvider);

  if (currentDir == null || libraryPath == null) return null;
  if (p.equals(currentDir, libraryPath)) return null;
  if (!p.isWithin(libraryPath, currentDir)) return null;

  final novels = await ref.watch(allNovelsProvider.future);
  final titleByFolder = {
    for (final novel in novels) novel.folderName: novel.title,
  };

  // Resolve the nearest registered novel folder using the shared rule (also
  // used to key bookmarks/reading-progress) so the title lookup is independent
  // of nesting depth. If no ancestor is a registered novel, fall back to the
  // first component's folder name (legacy title-based / organizational
  // folders) — the one piece of behavior unique to the title display.
  final novelId =
      resolveNovelId(libraryPath, currentDir, titleByFolder.keys.toSet());
  if (novelId != null) return titleByFolder[novelId];
  return p.split(p.relative(currentDir, from: libraryPath)).first;
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
