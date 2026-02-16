import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/domain/bookmark.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:path/path.dart' as p;

class BookmarkListPanel extends ConsumerWidget {
  const BookmarkListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novelId = ref.watch(currentNovelIdProvider);

    if (novelId == null) {
      return const Center(child: Text('作品フォルダを選択してください'));
    }

    final bookmarksAsync = ref.watch(bookmarksForNovelProvider(novelId));

    return bookmarksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('エラー: $error')),
      data: (bookmarks) {
        if (bookmarks.isEmpty) {
          return const Center(child: Text('ブックマークがありません'));
        }

        return ListView.builder(
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            return _buildBookmarkTile(context, ref, bookmark);
          },
        );
      },
    );
  }

  Widget _buildBookmarkTile(
    BuildContext context,
    WidgetRef ref,
    Bookmark bookmark,
  ) {
    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showContextMenu(context, ref, details.globalPosition, bookmark);
      },
      child: ListTile(
        leading: const Icon(Icons.bookmark),
        title: Text(bookmark.fileName),
        onTap: () => _openBookmark(context, ref, bookmark),
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
    Bookmark bookmark,
  ) async {
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'delete',
          child: Text('削除', style: TextStyle(color: Colors.red)),
        ),
      ],
    );

    if (value == 'delete') {
      await _deleteBookmark(ref, bookmark);
    }
  }

  Future<void> _deleteBookmark(WidgetRef ref, Bookmark bookmark) async {
    final repository = ref.read(bookmarkRepositoryProvider);
    await repository.remove(
      novelId: bookmark.novelId,
      filePath: bookmark.filePath,
    );
    ref.invalidate(bookmarksForNovelProvider(bookmark.novelId));
    ref.invalidate(isBookmarkedProvider);
  }

  void _openBookmark(
    BuildContext context,
    WidgetRef ref,
    Bookmark bookmark,
  ) {
    final file = File(bookmark.filePath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ファイルが見つかりません')),
      );
      return;
    }

    final directory = p.dirname(bookmark.filePath);
    ref.read(currentDirectoryProvider.notifier).setDirectory(directory);
    ref.read(selectedFileProvider.notifier).selectFile(
          FileEntry(name: bookmark.fileName, path: bookmark.filePath),
        );
  }
}
