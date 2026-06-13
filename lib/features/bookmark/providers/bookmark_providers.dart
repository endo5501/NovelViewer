import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/data/bookmark_repository.dart';
import 'package:novel_viewer/features/bookmark/domain/bookmark.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/shared/utils/novel_id_resolver.dart';

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository(ref.watch(novelDatabaseProvider));
});

/// Resolves the novel id for the current directory using the shared
/// nesting-aware rule [resolveNovelId] (nearest registered ancestor folder's
/// leaf name = `folder_name`). Async because the set of registered folder
/// names comes from [allNovelsProvider]. Resolves to null while the novel list
/// is still loading and at the library root / outside the library.
final currentNovelIdProvider = FutureProvider<String?>((ref) async {
  final currentDir = ref.watch(currentDirectoryProvider);
  final libraryPath = ref.watch(libraryPathProvider);

  if (currentDir == null || libraryPath == null) return null;

  final novels = await ref.watch(allNovelsProvider.future);
  final registeredFolderNames = {for (final n in novels) n.folderName};

  return resolveNovelId(libraryPath, currentDir, registeredFolderNames);
});

final bookmarksForNovelProvider =
    FutureProvider.family<List<Bookmark>, String>((ref, novelId) {
  final repository = ref.watch(bookmarkRepositoryProvider);
  return repository.findByNovel(novelId);
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
  required String novelId,
  required String fileName,
  required String filePath,
  required bool isCurrentlyBookmarked,
  int? lineNumber,
}) async {
  if (isCurrentlyBookmarked) {
    await repository.remove(
      novelId: novelId,
      filePath: filePath,
      lineNumber: lineNumber,
    );
  } else {
    await repository.add(
      novelId: novelId,
      fileName: fileName,
      filePath: filePath,
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
  final novelId = await ref.watch(currentNovelIdProvider.future);
  final selectedFile = ref.watch(selectedFileProvider);

  if (novelId == null || selectedFile == null) return [];

  final repository = ref.watch(bookmarkRepositoryProvider);
  final bookmarks = await repository.findByNovelAndFile(
    novelId: novelId,
    filePath: selectedFile.path,
  );
  return bookmarks
      .where((b) => b.lineNumber != null)
      .map((b) => b.lineNumber!)
      .toList();
});
