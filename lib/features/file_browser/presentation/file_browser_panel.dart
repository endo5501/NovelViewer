import 'package:flutter/material.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_delete/providers/novel_delete_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/features/file_browser/presentation/rename_title_dialog.dart';
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
              ? Center(child: Text(AppLocalizations.of(context)!.fileBrowser_selectFolderPrompt))
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
              tooltip: AppLocalizations.of(context)!.fileBrowser_goToParentFolder,
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
      error: (error, _) => Center(child: Text(AppLocalizations.of(context)!.common_errorPrefix(error.toString()))),
      data: (contents) {
        if (contents.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context)!.fileBrowser_noFilesFound));
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
        PopupMenuItem<String>(
          value: 'refresh',
          child: Text(AppLocalizations.of(context)!.fileBrowser_refreshMenuItem),
        ),
        PopupMenuItem<String>(
          value: 'rename',
          child: Text(AppLocalizations.of(context)!.fileBrowser_renameMenuItem),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(AppLocalizations.of(context)!.fileBrowser_deleteMenuItem, style: const TextStyle(color: Colors.red)),
        ),
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'refresh') {
        _startRefresh(context, ref, dir);
      } else if (value == 'rename') {
        _showRenameTitleDialog(context, ref, dir);
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
        SnackBar(content: Text(AppLocalizations.of(context)!.fileBrowser_downloadInProgressWarning)),
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

  void _showRenameTitleDialog(
    BuildContext context,
    WidgetRef ref,
    DirectoryEntry dir,
  ) {
    showDialog<String>(
      context: context,
      builder: (_) => RenameTitleDialog(currentTitle: dir.displayName),
    ).then((newTitle) async {
      if (newTitle == null || newTitle.isEmpty) return;
      if (newTitle == dir.displayName) return;
      try {
        final repository = ref.read(novelRepositoryProvider);
        await repository.updateTitle(dir.name, newTitle);
        ref.invalidate(allNovelsProvider);
        ref.invalidate(directoryContentsProvider);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.fileBrowser_renameFailed(e.toString()))),
        );
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
        title: Text(AppLocalizations.of(context)!.fileBrowser_deleteNovelTitle),
        content: Text(AppLocalizations.of(context)!.fileBrowser_deleteNovelConfirmation(dir.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.common_cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.common_deleteButton),
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
          SnackBar(content: Text(AppLocalizations.of(context)!.fileBrowser_deleteFailed(e.toString()))),
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
      title: Text(AppLocalizations.of(context)!.fileBrowser_refreshProgressTitle(novelTitle)),
      content: _buildContent(context, downloadState),
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
            child: Text(AppLocalizations.of(context)!.common_closeButton),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, DownloadState state) {
    final l10n = AppLocalizations.of(context)!;

    String episodeSummary(DownloadState s) {
      if (s.totalEpisodes <= 0) return '';
      final skipped =
          s.skippedEpisodes > 0 ? l10n.fileBrowser_skippedEpisodesSuffix(s.skippedEpisodes) : '';
      return l10n.fileBrowser_episodeCountFormat(s.totalEpisodes, skipped);
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
          l10n.fileBrowser_refreshCompleted(summary.isNotEmpty ? '\n$summary' : ''),
        );
      case DownloadStatus.error:
        return Text(
          l10n.common_errorPrefix(state.errorMessage ?? l10n.common_unknownError),
          style: const TextStyle(color: Colors.red),
        );
    }
  }
}
