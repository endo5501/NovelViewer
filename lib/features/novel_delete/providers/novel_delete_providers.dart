import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/novel_delete/data/novel_delete_service.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/shared/database/folder_db_handles.dart';

final novelDeleteServiceProvider =
    FutureProvider<NovelDeleteService>((ref) async {
  final novelDatabase = ref.watch(novelDatabaseProvider);
  final novelRepository = ref.watch(novelRepositoryProvider);
  final summaryRepository =
      await ref.watch(llmSummaryRepositoryProvider.future);
  final factCacheRepository =
      await ref.watch(factCacheRepositoryProvider.future);
  final readingProgressRepository =
      ref.watch(readingProgressRepositoryProvider);
  final bookmarkRepository = ref.watch(bookmarkRepositoryProvider);
  final fileSystemService = ref.watch(fileSystemServiceProvider);
  return NovelDeleteService(
    novelDatabase: novelDatabase,
    novelRepository: novelRepository,
    summaryRepository: summaryRepository,
    factCacheRepository: factCacheRepository,
    readingProgressRepository: readingProgressRepository,
    bookmarkRepository: bookmarkRepository,
    fileSystemService: fileSystemService,
    // Close the per-folder DB handles and WAIT for the close to finish before
    // the caller deletes the directory. The shared helper closes the cached
    // instances directly (a bare ref.invalidate is fire-and-forget and would
    // race the deletion), keys all three via folderDbKey, then invalidates.
    releaseFolderHandles: (directoryPath) => releaseFolderDbHandles(
      directoryPath,
      read: ref.read,
      invalidate: ref.invalidate,
    ),
  );
});
