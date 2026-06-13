import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/bookmark/data/bookmark_repository.dart';

class NovelDeleteService {
  final NovelDatabase novelDatabase;
  final NovelRepository novelRepository;
  final LlmSummaryRepository summaryRepository;
  final FactCacheRepository factCacheRepository;
  final ReadingProgressRepository readingProgressRepository;
  final BookmarkRepository bookmarkRepository;
  final FileSystemService fileSystemService;

  /// Releases (and awaits the close of) the per-folder database handles bound
  /// to [directoryPath] — `episode_cache.db`, `tts_audio.db`,
  /// `tts_dictionary.db`. Wired by the provider to the Riverpod family entries.
  /// Closing these BEFORE deleting the directory is essential on Windows, where
  /// an open SQLite connection holds an exclusive lock on the file and would
  /// otherwise make [FileSystemService.deleteDirectory] fail part-way.
  final Future<void> Function(String directoryPath)? releaseFolderHandles;

  NovelDeleteService({
    required this.novelDatabase,
    required this.novelRepository,
    required this.summaryRepository,
    required this.factCacheRepository,
    required this.readingProgressRepository,
    required this.bookmarkRepository,
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
    await fileSystemService.deleteDirectory(directoryPath);

    // 3. Only after the files are gone, remove the DB rows. All five tables
    //    live in `novel_metadata.db`, so we delete them in a single
    //    transaction: a failure part-way rolls back every delete, preventing
    //    the orphaned-row states described in F107/F127. `novel_id` for
    //    bookmarks/reading_progress equals the folder's leaf name
    //    (`folder_name`), matching the shared `resolveNovelId` key used when
    //    these rows are written.
    final db = await novelDatabase.database;
    await db.transaction((txn) async {
      await novelRepository.deleteByFolderName(folderName, txn: txn);
      await summaryRepository.deleteByFolderName(folderName, txn: txn);
      // Cascade the per-file fact cache so no rows are orphaned by the folder
      // deletion (see llm-summary-fact-cache "Cascade cleanup").
      await factCacheRepository.deleteByFolderName(folderName, txn: txn);
      await readingProgressRepository.deleteByNovelId(folderName, txn: txn);
      await bookmarkRepository.deleteByNovelId(folderName, txn: txn);
    });
  }
}
