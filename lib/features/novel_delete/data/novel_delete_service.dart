import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';

class NovelDeleteService {
  final NovelDatabase novelDatabase;
  final NovelRepository novelRepository;
  final ReadingProgressRepository readingProgressRepository;
  final FileSystemService fileSystemService;

  /// Releases (and awaits the close of) the per-folder database handles bound
  /// to [directoryPath] — `episode_cache.db`, `tts_audio.db`,
  /// `tts_dictionary.db`, `novel_data.db`. Wired by the provider to the
  /// Riverpod family entries. Closing these BEFORE deleting the directory is
  /// essential on Windows, where an open SQLite connection holds an exclusive
  /// lock on the file and would otherwise make
  /// [FileSystemService.deleteDirectory] fail part-way.
  final Future<void> Function(String directoryPath)? releaseFolderHandles;

  NovelDeleteService({
    required this.novelDatabase,
    required this.novelRepository,
    required this.readingProgressRepository,
    required this.fileSystemService,
    this.releaseFolderHandles,
  });

  Future<void> delete(String folderName, String directoryPath) async {
    // 1. Release per-folder DB handles and wait for their close to complete so
    //    no connection keeps the files locked.
    await releaseFolderHandles?.call(directoryPath);

    // 2. Delete the folder FIRST. If this throws (e.g. a file is still
    //    locked), we propagate the error and skip the DB cleanup below, so the
    //    metadata is preserved: the folder stays a registered novel folder and
    //    the user can retry the delete instead of being stuck with an
    //    undeletable "organizational" folder.
    //
    //    Deleting the directory also removes the novel's `novel_data.db`, which
    //    holds `word_summaries` / `fact_cache` / `bookmarks`. Those tables are
    //    therefore gone with the folder — there is no per-row cascade to run,
    //    and no orphan-row state can arise (cf. F107/F127).
    await fileSystemService.deleteDirectory(directoryPath);

    // 3. Only after the files are gone, remove the global `novel_metadata.db`
    //    rows that survive folder deletion: the `novels` catalog entry and the
    //    `reading_progress` row (kept global for the cross-novel "how far read"
    //    view). Both in a single transaction so a failure part-way rolls back
    //    every delete. `novel_id` for reading_progress equals the folder's leaf
    //    name (`folder_name`), matching the shared `resolveNovelId` key used
    //    when these rows are written.
    final db = await novelDatabase.database;
    await db.transaction((txn) async {
      await novelRepository.deleteByFolderName(folderName, txn: txn);
      await readingProgressRepository.deleteByNovelId(folderName, txn: txn);
    });
  }
}
