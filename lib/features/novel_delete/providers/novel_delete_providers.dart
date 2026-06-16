import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_delete/data/novel_delete_service.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/shared/database/folder_db_handles.dart';

final novelDeleteServiceProvider = FutureProvider<NovelDeleteService>((
  ref,
) async {
  final novelDatabase = ref.watch(novelDatabaseProvider);
  final novelRepository = ref.watch(novelRepositoryProvider);
  final readingProgressRepository = ref.watch(
    readingProgressRepositoryProvider,
  );
  final fileSystemService = ref.watch(fileSystemServiceProvider);
  return NovelDeleteService(
    novelDatabase: novelDatabase,
    novelRepository: novelRepository,
    readingProgressRepository: readingProgressRepository,
    fileSystemService: fileSystemService,
    // Close the per-folder DB handles and WAIT for the close to finish before
    // the caller deletes the directory, then invalidate the thin-view
    // providers so they don't keep serving the evicted (closed) handles. A
    // bare ref.invalidate is fire-and-forget and would race the deletion.
    releaseFolderHandles: (directoryPath) => releaseFolderDbHandles(
      directoryPath,
      read: ref.read,
      invalidate: ref.invalidate,
    ),
  );
});
