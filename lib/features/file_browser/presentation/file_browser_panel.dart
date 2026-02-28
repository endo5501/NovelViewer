import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_delete/providers/novel_delete_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';

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
            (file) {
              final ttsStatus = contents.ttsStatuses[file.name] ??
                  TtsEpisodeStatus.none;
              return ListTile(
                leading: const Icon(Icons.description),
                title: Text(file.name),
                trailing: switch (ttsStatus) {
                  TtsEpisodeStatus.completed =>
                    const Icon(Icons.check_circle, color: Colors.green),
                  TtsEpisodeStatus.partial =>
                    const Icon(Icons.pie_chart, color: Colors.orange),
                  TtsEpisodeStatus.none => null,
                },
                selected: selectedFile?.path == file.path,
                onTap: () {
                  ref.read(selectedFileProvider.notifier).selectFile(file);
                },
              );
            },
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
          value: 'refresh',
          child: Text('更新'),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('削除', style: TextStyle(color: Colors.red)),
        ),
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'refresh') {
        _startRefresh(context, ref, dir);
      } else if (value == 'delete') {
        _showDeleteConfirmation(context, ref, dir);
      }
    });
  }

  void _startRefresh(
    BuildContext context,
    WidgetRef ref,
    DirectoryEntry dir,
  ) {
    final downloadState = ref.read(downloadProvider);
    if (downloadState.status == DownloadStatus.downloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ダウンロード中です。完了後に再度お試しください')),
      );
      return;
    }

    ref.read(downloadProvider.notifier).refreshNovel(dir.name);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RefreshProgressDialog(novelTitle: dir.displayName),
    );
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

class _RefreshProgressDialog extends ConsumerWidget {
  final String novelTitle;

  const _RefreshProgressDialog({required this.novelTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);

    return AlertDialog(
      title: Text('「$novelTitle」を更新中'),
      content: _buildContent(downloadState),
      actions: [
        if (downloadState.status == DownloadStatus.completed ||
            downloadState.status == DownloadStatus.error)
          TextButton(
            onPressed: () {
              if (downloadState.status == DownloadStatus.completed) {
                ref.invalidate(allNovelsProvider);
                ref.invalidate(directoryContentsProvider);
              }
              ref.read(downloadProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            child: const Text('閉じる'),
          ),
      ],
    );
  }

  Widget _buildContent(DownloadState state) {
    String episodeSummary(DownloadState s) {
      if (s.totalEpisodes <= 0) return '';
      final skipped =
          s.skippedEpisodes > 0 ? '（${s.skippedEpisodes} スキップ）' : '';
      return '${s.totalEpisodes} エピソード$skipped';
    }

    switch (state.status) {
      case DownloadStatus.idle:
      case DownloadStatus.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            if (state.totalEpisodes > 0)
              Text(
                '${state.currentEpisode} / ${episodeSummary(state)}',
              ),
          ],
        );
      case DownloadStatus.completed:
        final summary = episodeSummary(state);
        return Text(
          '更新が完了しました。${summary.isNotEmpty ? '\n$summary' : ''}',
        );
      case DownloadStatus.error:
        return Text(
          'エラー: ${state.errorMessage ?? "不明なエラー"}',
          style: const TextStyle(color: Colors.red),
        );
    }
  }
}
