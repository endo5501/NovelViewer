import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/shared/widgets/search_summary_panel.dart';

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const _SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            const _SearchIntent(),
      },
      child: Actions(
        actions: {
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              final selectedText = ref.read(selectedTextProvider);
              if (selectedText?.isNotEmpty ?? false) {
                ref.read(searchQueryProvider.notifier).setQuery(selectedText);
              }
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
            body: const Row(
              children: [
                SizedBox(
                  width: 250,
                  child: FileBrowserPanel(key: Key('left_column')),
                ),
                VerticalDivider(width: 1),
                Expanded(
                  child: TextViewerPanel(key: Key('center_column')),
                ),
                VerticalDivider(width: 1),
                SizedBox(
                  width: 300,
                  child: SearchSummaryPanel(key: Key('right_column')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
