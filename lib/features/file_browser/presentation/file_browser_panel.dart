import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

class FileBrowserPanel extends ConsumerWidget {
  const FileBrowserPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDir = ref.watch(currentDirectoryProvider);

    return Column(
      children: [
        _buildToolbar(context, ref, currentDir),
        const Divider(height: 1),
        Expanded(
          child: currentDir == null
              ? const Center(child: Text('フォルダを選択してください'))
              : _buildFileList(ref),
        ),
      ],
    );
  }

  Widget _buildToolbar(
      BuildContext context, WidgetRef ref, String? currentDir) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (currentDir != null)
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: () => _navigateToParent(ref, currentDir),
              tooltip: '親フォルダへ',
            ),
        ],
      ),
    );
  }

  Widget _buildFileList(WidgetRef ref) {
    final contentsAsync = ref.watch(directoryContentsProvider);
    final selectedFile = ref.watch(selectedFileProvider);

    return contentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('エラー: $error')),
      data: (contents) {
        if (contents.isEmpty) {
          return const Center(child: Text('テキストファイルが見つかりません'));
        }

        final items = <Widget>[];

        for (final dir in contents.subdirectories) {
          items.add(
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(dir.name),
              onTap: () {
                ref
                    .read(currentDirectoryProvider.notifier)
                    .setDirectory(dir.path);
                ref.read(selectedFileProvider.notifier).clear();
              },
            ),
          );
        }

        for (final file in contents.files) {
          final isSelected = selectedFile?.path == file.path;
          items.add(
            ListTile(
              leading: const Icon(Icons.description),
              title: Text(file.name),
              selected: isSelected,
              onTap: () {
                ref.read(selectedFileProvider.notifier).selectFile(file);
              },
            ),
          );
        }

        return ListView(children: items);
      },
    );
  }

  void _navigateToParent(WidgetRef ref, String currentDir) {
    final parent = currentDir.substring(0, currentDir.lastIndexOf('/'));
    if (parent.isNotEmpty) {
      ref.read(currentDirectoryProvider.notifier).setDirectory(parent);
      ref.read(selectedFileProvider.notifier).clear();
    }
  }
}
