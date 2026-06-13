import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/novel_delete/data/novel_delete_service.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';

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
    releaseFolderHandles: (directoryPath) async {
      // Close the per-folder DB handles and WAIT for the close to finish
      // before the caller deletes the directory. `ref.invalidate` alone is
      // fire-and-forget (its onDispose close is not awaited), which would race
      // the file deletion — so we close the cached instances directly first,
      // then invalidate to drop the disposed entries. episode_cache uses the
      // canonical key so the download flow's handle is reachable here.
      final cacheKey = folderDbKey(directoryPath);
      await ref.read(episodeCacheDatabaseProvider(cacheKey)).close();
      await ref.read(ttsAudioDatabaseProvider(directoryPath)).close();
      await ref.read(ttsDictionaryDatabaseProvider(directoryPath)).close();
      ref.invalidate(episodeCacheDatabaseProvider(cacheKey));
      ref.invalidate(ttsAudioDatabaseProvider(directoryPath));
      ref.invalidate(ttsDictionaryDatabaseProvider(directoryPath));
    },
  );
});
