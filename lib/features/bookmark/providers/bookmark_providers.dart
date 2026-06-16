import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/data/bookmark_repository.dart';
import 'package:novel_viewer/features/bookmark/domain/bookmark.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';
import 'package:novel_viewer/shared/database/novel_data_database_provider.dart';
import 'package:novel_viewer/shared/utils/novel_id_resolver.dart';

/// Folder-scoped `BookmarkRepository`, backed by the novel's per-folder
/// `novel_data.db`. The family argument is the novel folder's absolute path.
final bookmarkRepositoryProvider =
    FutureProvider.family<BookmarkRepository, String>((ref, folderPath) async {
  // Normalize via folderDbKey so the resolved novel_data.db thin-view matches
  // the one the registry/folder-switch flow evicts & invalidates.
  final db = await ref
      .watch(novelDataDatabaseProvider(folderDbKey(folderPath)))
      .database;
  return BookmarkRepository(db);
});

/// Resolves the **absolute path of the current novel's folder** (the folder
/// that owns its `novel_data.db`) using the shared nesting-aware rule
/// [resolveNovelFolderPath]. Resolves to null while the novel list is still
/// loading and at the library root / outside the library.
final currentNovelFolderPathProvider = FutureProvider<String?>((ref) async {
  final currentDir = ref.watch(currentDirectoryProvider);
  final libraryPath = ref.watch(libraryPathProvider);

  if (currentDir == null || libraryPath == null) return null;

  final novels = await ref.watch(allNovelsProvider.future);
  final registeredFolderNames = {for (final n in novels) n.folderName};

  return resolveNovelFolderPath(libraryPath, currentDir, registeredFolderNames);
});

/// All bookmarks for the current novel (resolved via
/// [currentNovelFolderPathProvider]), most-recent first. Empty when not inside
/// a registered novel folder.
final bookmarksForCurrentNovelProvider =
    FutureProvider<List<Bookmark>>((ref) async {
  final folderPath = await ref.watch(currentNovelFolderPathProvider.future);
  if (folderPath == null) return const [];
  final repository = await ref.watch(bookmarkRepositoryProvider(folderPath).future);
  return repository.findAll();
});

final isBookmarkedProvider = Provider<bool>((ref) {
  final lineNumber = ref.watch(currentViewLineProvider);
  final linesAsync = ref.watch(bookmarkLineNumbersForFileProvider);
  return linesAsync.maybeWhen(
    data: (lines) => lines.contains(lineNumber),
    orElse: () => false,
  );
});

Future<void> toggleBookmark(
  BookmarkRepository repository, {
  required String fileName,
  required bool isCurrentlyBookmarked,
  int? lineNumber,
}) async {
  if (isCurrentlyBookmarked) {
    await repository.remove(
      fileName: fileName,
      lineNumber: lineNumber,
    );
  } else {
    await repository.add(
      fileName: fileName,
      lineNumber: lineNumber,
    );
  }
}

class CurrentViewLineNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? lineNumber) => state = lineNumber;
  void reset() => state = null;
}

final currentViewLineProvider =
    NotifierProvider<CurrentViewLineNotifier, int?>(
        CurrentViewLineNotifier.new);

class BookmarkJumpLineNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void jump(int lineNumber) => state = lineNumber;
  void clear() => state = null;
}

final bookmarkJumpLineProvider =
    NotifierProvider<BookmarkJumpLineNotifier, int?>(
        BookmarkJumpLineNotifier.new);

final bookmarkLineNumbersForFileProvider =
    FutureProvider<List<int>>((ref) async {
  final folderPath = await ref.watch(currentNovelFolderPathProvider.future);
  final selectedFile = ref.watch(selectedFileProvider);

  if (folderPath == null || selectedFile == null) return [];

  final repository =
      await ref.watch(bookmarkRepositoryProvider(folderPath).future);
  final bookmarks = await repository.findByFile(fileName: selectedFile.name);
  return bookmarks
      .where((b) => b.lineNumber != null)
      .map((b) => b.lineNumber!)
      .toList();
});
