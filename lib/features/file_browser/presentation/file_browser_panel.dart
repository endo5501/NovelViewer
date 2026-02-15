import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_delete/providers/novel_delete_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';

/// Returns the parent directory of [currentDir], or null if already at root.
String? getParentDirectory(String currentDir) {
  final parent = p.dirname(currentDir);
  if (parent == currentDir) return null;
  return parent;
}

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
              : _buildFileList(context, ref),
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

  bool _isLibraryRoot(WidgetRef ref) {
    final currentDir = ref.read(currentDirectoryProvider);
    final libraryPath = ref.read(libraryPathProvider);
    return libraryPath != null && currentDir == libraryPath;
  }

  Widget _buildFileList(BuildContext context, WidgetRef ref) {
    final contentsAsync = ref.watch(directoryContentsProvider);
    final selectedFile = ref.watch(selectedFileProvider);

    return contentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('エラー: $error')),
      data: (contents) {
        if (contents.isEmpty) {
          return const Center(child: Text('テキストファイルが見つかりません'));
        }

        final isAtLibraryRoot = _isLibraryRoot(ref);
        final items = [
          ...contents.subdirectories.map(
            (dir) => _buildDirectoryTile(context, ref, dir, isAtLibraryRoot),
          ),
          ...contents.files.map(
            (file) => ListTile(
              leading: const Icon(Icons.description),
              title: Text(file.name),
              selected: selectedFile?.path == file.path,
              onTap: () {
                ref.read(selectedFileProvider.notifier).selectFile(file);
              },
            ),
          ),
        ];

        return ListView(children: items);
      },
    );
  }

  Widget _buildDirectoryTile(
    BuildContext context,
    WidgetRef ref,
    DirectoryEntry dir,
    bool isAtLibraryRoot,
  ) {
    final tile = ListTile(
      leading: const Icon(Icons.folder),
      title: Text(dir.displayName),
      onTap: () {
        ref.read(currentDirectoryProvider.notifier).setDirectory(dir.path);
        ref.read(selectedFileProvider.notifier).clear();
      },
    );

    if (!isAtLibraryRoot) return tile;

    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showContextMenu(context, ref, details.globalPosition, dir);
      },
      child: tile,
    );
  }

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
    DirectoryEntry dir,
  ) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('削除', style: TextStyle(color: Colors.red)),
        ),
      ],
    ).then((value) {
      if (value == 'delete' && context.mounted) {
        _showDeleteConfirmation(context, ref, dir);
      }
    });
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    DirectoryEntry dir,
  ) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('小説を削除'),
        content: Text('「${dir.displayName}」を削除しますか？\nすべてのエピソードとデータが完全に削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      try {
        final deleteService =
            await ref.read(novelDeleteServiceProvider.future);
        await deleteService.delete(dir.name, dir.path);
        ref.invalidate(allNovelsProvider);
        ref.invalidate(directoryContentsProvider);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    });
  }

  void _navigateToParent(WidgetRef ref, String currentDir) {
    final parent = getParentDirectory(currentDir);
    if (parent != null) {
      ref.read(currentDirectoryProvider.notifier).setDirectory(parent);
      ref.read(selectedFileProvider.notifier).clear();
    }
  }
}
