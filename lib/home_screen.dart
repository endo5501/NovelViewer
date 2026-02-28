import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/presentation/left_column_panel.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/shared/providers/layout_providers.dart';
import 'package:novel_viewer/shared/widgets/search_summary_panel.dart';

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class _DismissSearchIntent extends Intent {
  const _DismissSearchIntent();
}

class _BookmarkIntent extends Intent {
  const _BookmarkIntent();
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Widget _buildBookmarkButton(WidgetRef ref) {
    final novelId = ref.watch(currentNovelIdProvider);
    final selectedFile = ref.watch(selectedFileProvider);
    final isEnabled = novelId != null && selectedFile != null;
    final isBookmarked = ref.watch(isBookmarkedProvider).value ?? false;

    return IconButton(
      key: const Key('bookmark_button'),
      icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
      onPressed: isEnabled ? () => _toggleBookmark(ref) : null,
      tooltip: isBookmarked ? 'ブックマーク解除' : 'ブックマーク登録',
    );
  }

  Future<void> _toggleBookmark(WidgetRef ref) async {
    final novelId = ref.read(currentNovelIdProvider);
    final selectedFile = ref.read(selectedFileProvider);
    if (novelId == null || selectedFile == null) return;

    final isBookmarked = ref.read(isBookmarkedProvider).value ?? false;
    final repository = ref.read(bookmarkRepositoryProvider);

    await toggleBookmark(
      repository,
      novelId: novelId,
      fileName: selectedFile.name,
      filePath: selectedFile.path,
      isCurrentlyBookmarked: isBookmarked,
    );

    ref.invalidate(isBookmarkedProvider);
    ref.invalidate(bookmarksForNovelProvider(novelId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const _SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            const _SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const _DismissSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            const _BookmarkIntent(),
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
            const _BookmarkIntent(),
      },
      child: Actions(
        actions: {
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              final selectedText = ref.read(selectedTextProvider);
              if (selectedText?.isNotEmpty ?? false) {
                ref.read(searchQueryProvider.notifier).setQuery(selectedText);
              } else {
                ref.read(searchBoxVisibleProvider.notifier).show();
              }
              if (!ref.read(rightColumnVisibleProvider)) {
                ref.read(rightColumnVisibleProvider.notifier).toggle();
              }
              return null;
            },
          ),
          _DismissSearchIntent: CallbackAction<_DismissSearchIntent>(
            onInvoke: (_) {
              final isSearchActive =
                  ref.read(searchBoxVisibleProvider) ||
                  ref.read(searchQueryProvider) != null;
              if (isSearchActive) {
                ref.read(searchBoxVisibleProvider.notifier).hide();
                ref.read(searchQueryProvider.notifier).setQuery(null);
              }
              return null;
            },
          ),
          _BookmarkIntent: CallbackAction<_BookmarkIntent>(
            onInvoke: (_) {
              _toggleBookmark(ref);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                ref.watch(selectedNovelTitleProvider).value ??
                    'NovelViewer',
              ),
              actions: [
                _buildBookmarkButton(ref),
                IconButton(
                  key: const Key('toggle_right_column_button'),
                  icon: Icon(
                    ref.watch(rightColumnVisibleProvider)
                        ? Icons.vertical_split
                        : Icons.view_sidebar,
                  ),
                  onPressed: () => ref
                      .read(rightColumnVisibleProvider.notifier)
                      .toggle(),
                  tooltip: ref.watch(rightColumnVisibleProvider)
                      ? '右カラムを非表示'
                      : '右カラムを表示',
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => DownloadDialog.show(context),
                  tooltip: '小説ダウンロード',
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => SettingsDialog.show(context),
                ),
              ],
            ),
            body: Row(
              children: [
                const SizedBox(
                  width: 250,
                  child: LeftColumnPanel(key: Key('left_column')),
                ),
                const VerticalDivider(width: 1),
                const Expanded(
                  child: TextViewerPanel(key: Key('center_column')),
                ),
                if (ref.watch(rightColumnVisibleProvider)) ...[
                  const VerticalDivider(width: 1),
                  const SizedBox(
                    width: 300,
                    child: SearchSummaryPanel(key: Key('right_column')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
