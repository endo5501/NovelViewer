import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/features/bookmark/domain/bookmark.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:path/path.dart' as p;

class BookmarkListPanel extends ConsumerWidget {
  const BookmarkListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novelId = ref.watch(currentNovelIdProvider).value;

    if (novelId == null) {
      return Center(child: Text(AppLocalizations.of(context)!.bookmark_selectNovelPrompt));
    }

    final bookmarksAsync = ref.watch(bookmarksForNovelProvider(novelId));

    return bookmarksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(AppLocalizations.of(context)!.common_errorPrefix(error.toString()))),
      data: (bookmarks) {
        if (bookmarks.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context)!.bookmark_noBookmarks));
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
        title: Text(bookmark.lineNumber != null
            ? '${bookmark.fileName} : L${bookmark.lineNumber}'
            : bookmark.fileName),
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
      items: [
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(AppLocalizations.of(context)!.bookmark_deleteMenuItem, style: const TextStyle(color: Colors.red)),
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
      fileName: bookmark.fileName,
      lineNumber: bookmark.lineNumber,
    );
    ref.invalidate(bookmarksForNovelProvider(bookmark.novelId));
    ref.invalidate(bookmarkLineNumbersForFileProvider);
    ref.invalidate(isBookmarkedProvider);
  }

  void _openBookmark(
    BuildContext context,
    WidgetRef ref,
    Bookmark bookmark,
  ) {
    // Reconstruct the target path from the novel's *current* folder + the
    // bookmark's file_name (no absolute path is persisted). The panel only
    // lists bookmarks for the current novel, so currentDirectory is that
    // novel's folder. existsSync stays as a fail-safe for the rare case the
    // file is gone (e.g. a renumber after refresh).
    final currentDir = ref.read(currentDirectoryProvider);
    final resolvedPath =
        currentDir == null ? null : p.join(currentDir, bookmark.fileName);
    if (resolvedPath == null || !File(resolvedPath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.bookmark_fileNotFound)),
      );
      return;
    }

    ref.read(selectedFileProvider.notifier).selectFile(
          FileEntry(name: bookmark.fileName, path: resolvedPath),
        );
    if (bookmark.lineNumber != null) {
      ref.read(bookmarkJumpLineProvider.notifier).jump(bookmark.lineNumber!);
    }
  }
}
