import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/features/bookmark/data/bookmark_repository.dart';
import 'package:novel_viewer/features/bookmark/domain/bookmark.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository(ref.watch(novelDatabaseProvider));
});

final currentNovelIdProvider = Provider<String?>((ref) {
  final currentDir = ref.watch(currentDirectoryProvider);
  final libraryPath = ref.watch(libraryPathProvider);

  if (currentDir == null || libraryPath == null) return null;
  if (p.equals(currentDir, libraryPath)) return null;
  if (!p.isWithin(libraryPath, currentDir)) return null;

  final relativePath = p.relative(currentDir, from: libraryPath);
  return p.split(relativePath).first;
});

final bookmarksForNovelProvider =
    FutureProvider.family<List<Bookmark>, String>((ref, novelId) {
  final repository = ref.watch(bookmarkRepositoryProvider);
  return repository.findByNovel(novelId);
});

final isBookmarkedProvider = FutureProvider<bool>((ref) async {
  final novelId = ref.watch(currentNovelIdProvider);
  final selectedFile = ref.watch(selectedFileProvider);

  if (novelId == null || selectedFile == null) return false;

  final repository = ref.watch(bookmarkRepositoryProvider);
  return repository.exists(novelId: novelId, filePath: selectedFile.path);
});

Future<void> toggleBookmark(
  BookmarkRepository repository, {
  required String novelId,
  required String fileName,
  required String filePath,
  required bool isCurrentlyBookmarked,
}) async {
  if (isCurrentlyBookmarked) {
    await repository.remove(novelId: novelId, filePath: filePath);
  } else {
    await repository.add(
      novelId: novelId,
      fileName: fileName,
      filePath: filePath,
    );
  }
}
