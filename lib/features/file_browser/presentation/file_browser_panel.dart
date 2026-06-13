import 'dart:io' show FileSystemException;

import 'package:flutter/material.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/domain/novel_folder_classifier.dart';
import 'package:novel_viewer/features/file_browser/domain/move_destination.dart';
import 'package:novel_viewer/features/file_browser/domain/move_follow.dart';
import 'package:novel_viewer/features/file_browser/presentation/move_destination_dialog.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_delete/providers/novel_delete_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/features/file_browser/presentation/rename_title_dialog.dart';
import 'package:novel_viewer/features/file_browser/presentation/new_folder_dialog.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode_status.dart';
import 'package:novel_viewer/shared/database/folder_db_handles.dart';

/// Returns the parent directory of [currentDir], or null if navigation up is
/// not allowed.
///
/// When [libraryPath] is provided, navigation is confined to the library: the
/// function returns null when [currentDir] is at (or outside) the library
/// root, so the file browser never escapes the NovelViewer folder. Without
/// [libraryPath] it falls back to the filesystem root as the boundary.
String? getParentDirectory(String currentDir, {String? libraryPath}) {
  if (libraryPath != null) {
    if (p.equals(currentDir, libraryPath)) return null;
    if (!p.isWithin(libraryPath, currentDir)) return null;
  }
  final parent = p.dirname(currentDir);
  if (parent == currentDir) return null;
  return parent;
}

class FileBrowserPanel extends ConsumerStatefulWidget {
  const FileBrowserPanel({super.key});

  @override
  ConsumerState<FileBrowserPanel> createState() => _FileBrowserPanelState();
}

/// Fixed row height used both for `ListView.itemExtent` and for the index-
/// based scroll offset estimate. ListView's lazy materialisation means an
/// off-screen tile has no `BuildContext`, so we cannot rely on
/// `Scrollable.ensureVisible` against a per-tile GlobalKey for items that
/// have never been painted. A fixed itemExtent lets us compute the target
/// scroll offset directly from the item index.
const double _kFileTileExtent = 56.0;

class _FileBrowserPanelState extends ConsumerState<FileBrowserPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll the selected file into view whenever the selection
    // transitions to a new file (programmatic selection or a tap). Skipping
    // when the path is unchanged guards against unrelated rebuilds and
    // re-selection no-ops.
    ref.listenManual<FileEntry?>(selectedFileProvider, (prev, next) {
      if (next == null) return;
      if (prev?.path == next.path) return;
      _scheduleScrollTo(next);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollTo(FileEntry file) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final contents = ref.read(directoryContentsProvider).value;
      if (contents == null) return;
      final fileIndex =
          contents.files.indexWhere((f) => f.path == file.path);
      if (fileIndex < 0) return;
      // Files render after subdirectories in the flat item list.
      final flatIndex = contents.subdirectories.length + fileIndex;
      final viewportHeight =
          _scrollController.position.viewportDimension;
      // Centre the target row in the viewport when possible.
      final targetOffset =
          flatIndex * _kFileTileExtent - (viewportHeight - _kFileTileExtent) / 2;
      final clamped = targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentDir = ref.watch(currentDirectoryProvider);

    return Column(
      children: [
        _buildToolbar(context, currentDir),
        const Divider(height: 1),
        Expanded(
          child: currentDir == null
              ? Center(
                  child: Text(AppLocalizations.of(context)!
                      .fileBrowser_selectFolderPrompt))
              : _buildFileList(context),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, String? currentDir) {
    var hasParent = false;
    if (currentDir != null) {
      final libraryPath = ref.watch(libraryPathProvider);
      hasParent =
          getParentDirectory(currentDir, libraryPath: libraryPath) != null;
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (currentDir != null)
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed:
                  hasParent ? () => _navigateToParent(currentDir) : null,
              tooltip: AppLocalizations.of(context)!
                  .fileBrowser_goToParentFolder,
            ),
          if (currentDir != null)
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              onPressed: () => _showNewFolderDialog(context, currentDir),
              tooltip:
                  AppLocalizations.of(context)!.fileBrowser_newFolderTooltip,
            ),
        ],
      ),
    );
  }

  void _showNewFolderDialog(BuildContext context, String currentDir) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<String>(
      context: context,
      builder: (_) => NewFolderDialog(title: l10n.fileBrowser_newFolderTitle),
    ).then((name) async {
      if (name == null || name.isEmpty) return;
      try {
        await ref
            .read(fileSystemServiceProvider)
            .createDirectory(currentDir, name);
        if (!context.mounted) return;
        ref.invalidate(directoryContentsProvider);
      } on DirectoryOpException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_directoryOpMessage(context, e))),
        );
      }
    });
  }

  /// Maps a [DirectoryOpException] to a localized, user-facing message.
  String _directoryOpMessage(BuildContext context, DirectoryOpException e) {
    final l10n = AppLocalizations.of(context)!;
    return switch (e.error) {
      DirectoryOpError.invalidName => l10n.fileBrowser_errorInvalidName,
      DirectoryOpError.nameCollision => l10n.fileBrowser_errorNameCollision,
      DirectoryOpError.notEmpty => l10n.fileBrowser_errorFolderNotEmpty,
      DirectoryOpError.intoSelfOrDescendant =>
        l10n.fileBrowser_errorMoveIntoSelf,
      DirectoryOpError.sourceNotFound => l10n.common_unknownError,
      DirectoryOpError.ioFailure => l10n.common_unknownError,
    };
  }

  Widget _buildFileList(BuildContext context) {
    final contentsAsync = ref.watch(directoryContentsProvider);
    final selectedFile = ref.watch(selectedFileProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return contentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
          child: Text(AppLocalizations.of(context)!
              .common_errorPrefix(error.toString()))),
      data: (contents) {
        if (contents.isEmpty) {
          return Center(
              child: Text(AppLocalizations.of(context)!
                  .fileBrowser_noFilesFound));
        }

        // The set of registered novel folder names lets us classify each
        // subdirectory as a novel folder vs an organizational folder at any
        // depth (see [isNovelFolder]).
        final novels = ref.watch(allNovelsProvider).value ?? const [];
        final novelFolderNames = <String>{
          for (final n in novels) n.folderName,
        };
        final items = [
          ...contents.subdirectories.map(
            (dir) => _buildDirectoryTile(
              context,
              dir,
              isNovelFolder(dir.name, novelFolderNames),
            ),
          ),
          ...contents.files.map(
            (file) => _buildFileTile(
              context,
              file: file,
              contents: contents,
              isSelected: selectedFile?.path == file.path,
              colorScheme: colorScheme,
            ),
          ),
        ];

        return ListView(
          controller: _scrollController,
          itemExtent: _kFileTileExtent,
          children: items,
        );
      },
    );
  }

  Widget _buildFileTile(
    BuildContext context, {
    required FileEntry file,
    required DirectoryContents contents,
    required bool isSelected,
    required ColorScheme colorScheme,
  }) {
    final ttsStatus = contents.ttsStatuses[file.name];

    final tile = ListTile(
      leading: const Icon(Icons.description),
      title: Text(
        file.name,
        style: isSelected
            ? const TextStyle(fontWeight: FontWeight.w600)
            : null,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: switch (ttsStatus) {
        TtsEpisodeStatus.completed =>
          const Icon(Icons.check_circle, color: Colors.green),
        TtsEpisodeStatus.partial || TtsEpisodeStatus.generating =>
          const Icon(Icons.pie_chart, color: Colors.orange),
        null => null,
      },
      selected: isSelected,
      onTap: () {
        ref.read(selectedFileProvider.notifier).selectFile(file);
      },
    );

    if (!isSelected) return tile;

    // Wrap the ListTile in a transparent Material so the tile paints its
    // selection background and ink splashes on that Material rather than
    // through the outer DecoratedBox, which Flutter asserts against in
    // newer stable releases.
    return Container(
      key: const Key('selected_file_tile_decoration'),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        border: Border(
          left: BorderSide(color: colorScheme.primary, width: 4),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: tile,
      ),
    );
  }

  Widget _buildDirectoryTile(
    BuildContext context,
    DirectoryEntry dir,
    bool isNovel,
  ) {
    final tile = ListTile(
      leading: Icon(isNovel ? Icons.menu_book : Icons.folder),
      title: Text(
        dir.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        ref.read(currentDirectoryProvider.notifier).setDirectory(dir.path);
        ref.read(selectedFileProvider.notifier).clear();
      },
    );

    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showContextMenu(context, details.globalPosition, dir, isNovel);
      },
      child: tile,
    );
  }

  void _showContextMenu(
    BuildContext context,
    Offset position,
    DirectoryEntry dir,
    bool isNovel,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final items = <PopupMenuEntry<String>>[
      if (isNovel)
        PopupMenuItem<String>(
          value: 'refresh',
          child: Text(l10n.fileBrowser_refreshMenuItem),
        ),
      if (isNovel)
        PopupMenuItem<String>(
          value: 'renameTitle',
          child: Text(l10n.fileBrowser_renameMenuItem),
        )
      else
        PopupMenuItem<String>(
          value: 'renameFolder',
          child: Text(l10n.fileBrowser_renameFolderMenuItem),
        ),
      PopupMenuItem<String>(
        value: 'move',
        child: Text(l10n.fileBrowser_moveMenuItem),
      ),
      PopupMenuItem<String>(
        value: isNovel ? 'delete' : 'deleteFolder',
        child: Text(l10n.fileBrowser_deleteMenuItem,
            style: const TextStyle(color: Colors.red)),
      ),
    ];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: items,
    ).then((value) {
      if (!context.mounted) return;
      switch (value) {
        case 'refresh':
          _startRefresh(context, dir);
        case 'renameTitle':
          _showRenameTitleDialog(context, dir);
        case 'renameFolder':
          _showRenameFolderDialog(context, dir);
        case 'move':
          _showMoveDialog(context, dir);
        case 'delete':
          _showDeleteConfirmation(context, dir);
        case 'deleteFolder':
          _showDeleteFolderConfirmation(context, dir);
      }
    });
  }

  Future<void> _showMoveDialog(
    BuildContext context,
    DirectoryEntry dir,
  ) async {
    final libraryPath = ref.read(libraryPathProvider);
    if (libraryPath == null) return;

    final novels = ref.read(allNovelsProvider).value ?? const [];
    final novelFolderNames = <String>{
      for (final n in novels) n.folderName,
    };
    final service = ref.read(fileSystemServiceProvider);

    final List<String> orgPaths;
    try {
      orgPaths =
          await service.listOrganizationalFolderTree(libraryPath, novelFolderNames);
    } on FileSystemException {
      return;
    }
    if (!context.mounted) return;

    final destinations = buildMoveDestinations(
      libraryPath: libraryPath,
      organizationalFolderPaths: orgPaths,
      sourcePath: dir.path,
    );

    final destination = await showDialog<String>(
      context: context,
      builder: (_) => MoveDestinationDialog(destinations: destinations),
    );
    if (destination == null) return;
    if (!context.mounted) return;

    final currentDir = ref.read(currentDirectoryProvider);
    try {
      // Release per-folder DB handles BEFORE moving so an open SQLite file
      // does not block the rename (Windows holds an exclusive lock). Awaiting
      // the close is required: a bare ref.invalidate is fire-and-forget and
      // would race the file operation.
      await releaseFolderDbHandles(dir.path,
          read: ref.read, invalidate: ref.invalidate);
      final newPath = await service.moveDirectory(dir.path, destination);
      if (!context.mounted) return;
      // Keep the browser pointed at the moved content if it was open.
      final followed = followedCurrentDirectory(
        currentDir: currentDir,
        sourcePath: dir.path,
        newSourcePath: newPath,
      );
      if (followed != null) {
        ref.read(currentDirectoryProvider.notifier).setDirectory(followed);
      }
      ref.invalidate(directoryContentsProvider);
    } on DirectoryOpException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_directoryOpMessage(context, e))),
      );
    }
  }

  void _showDeleteFolderConfirmation(BuildContext context, DirectoryEntry dir) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.fileBrowser_deleteFolderTitle),
        content:
            Text(l10n.fileBrowser_deleteFolderConfirmation(dir.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.common_deleteButton),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      try {
        await releaseFolderDbHandles(dir.path,
            read: ref.read, invalidate: ref.invalidate);
        await ref
            .read(fileSystemServiceProvider)
            .deleteEmptyDirectory(dir.path);
        if (!context.mounted) return;
        ref.invalidate(directoryContentsProvider);
      } on DirectoryOpException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_directoryOpMessage(context, e))),
        );
      }
    });
  }

  void _showRenameFolderDialog(BuildContext context, DirectoryEntry dir) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<String>(
      context: context,
      builder: (_) => NewFolderDialog(
        title: l10n.fileBrowser_renameFolderTitle,
        initialName: dir.name,
        confirmLabel: l10n.common_changeButton,
      ),
    ).then((newName) async {
      if (newName == null || newName.isEmpty || newName == dir.name) return;
      try {
        // Renaming changes the folder's absolute path, so release any per-
        // folder DB handles bound to the old path first (awaited close, not a
        // fire-and-forget invalidate).
        await releaseFolderDbHandles(dir.path,
            read: ref.read, invalidate: ref.invalidate);
        await ref
            .read(fileSystemServiceProvider)
            .renameDirectory(dir.path, newName);
        if (!context.mounted) return;
        ref.invalidate(directoryContentsProvider);
      } on DirectoryOpException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_directoryOpMessage(context, e))),
        );
      }
    });
  }

  void _startRefresh(BuildContext context, DirectoryEntry dir) {
    final downloadState = ref.read(downloadProvider);
    if (downloadState.status == DownloadStatus.downloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .fileBrowser_downloadInProgressWarning)),
      );
      return;
    }

    ref.read(downloadProvider.notifier).refreshNovel(dir.name);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _RefreshProgressDialog(novelTitle: dir.displayName),
    );
  }

  void _showRenameTitleDialog(BuildContext context, DirectoryEntry dir) {
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
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .fileBrowser_renameFailed(e.toString()))),
        );
      }
    });
  }

  void _showDeleteConfirmation(BuildContext context, DirectoryEntry dir) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            AppLocalizations.of(context)!.fileBrowser_deleteNovelTitle),
        content: Text(AppLocalizations.of(context)!
            .fileBrowser_deleteNovelConfirmation(dir.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                Text(AppLocalizations.of(context)!.common_cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child:
                Text(AppLocalizations.of(context)!.common_deleteButton),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      try {
        // Drop any active watcher bound to the folder being deleted before the
        // delete flow closes its per-folder DB handles. Otherwise the watcher
        // would immediately re-materialize (and re-open) the handle right
        // after it is closed, re-locking the file on Windows.
        //
        // Two watchers can point into the target folder:
        //  - the file browser, when the current directory is inside it;
        //  - the text viewer / TtsControlsBar, via the selected file, which
        //    drives ttsAudioStateProvider -> ttsAudioDatabaseProvider.
        final currentDir = ref.read(currentDirectoryProvider);
        if (currentDir != null &&
            (p.equals(currentDir, dir.path) ||
                p.isWithin(dir.path, currentDir))) {
          final libraryPath = ref.read(libraryPathProvider);
          final parent =
              getParentDirectory(dir.path, libraryPath: libraryPath) ??
                  p.dirname(dir.path);
          ref.read(currentDirectoryProvider.notifier).setDirectory(parent);
        }
        final selectedFile = ref.read(selectedFileProvider);
        if (selectedFile != null &&
            p.isWithin(dir.path, selectedFile.path)) {
          ref.read(selectedFileProvider.notifier).clear();
        }
        final deleteService =
            await ref.read(novelDeleteServiceProvider.future);
        await deleteService.delete(dir.name, dir.path);
        ref.invalidate(allNovelsProvider);
        ref.invalidate(directoryContentsProvider);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .fileBrowser_deleteFailed(e.toString()))),
        );
      }
    });
  }

  void _navigateToParent(String currentDir) {
    final libraryPath = ref.read(libraryPathProvider);
    final parent = getParentDirectory(currentDir, libraryPath: libraryPath);
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
      title: Text(AppLocalizations.of(context)!
          .fileBrowser_refreshProgressTitle(novelTitle)),
      content: _buildContent(context, downloadState),
      actions: [
        if (downloadState.status == DownloadStatus.completed ||
            downloadState.status == DownloadStatus.error ||
            downloadState.status == DownloadStatus.cancelled)
          TextButton(
            onPressed: () {
              if (downloadState.status == DownloadStatus.completed) {
                ref.invalidate(allNovelsProvider);
                ref.invalidate(directoryContentsProvider);
              }
              ref.read(downloadProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            child:
                Text(AppLocalizations.of(context)!.common_closeButton),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, DownloadState state) {
    final l10n = AppLocalizations.of(context)!;

    String failedSuffix(int failed) {
      if (failed <= 0) return '';
      final lang = Localizations.localeOf(context).languageCode;
      return switch (lang) {
        'ja' => ' (失敗: $failed件)',
        'zh' => ' （失败：$failed个）',
        _ => ' (failed: $failed)',
      };
    }

    String episodeSummary(DownloadState s) {
      if (s.totalEpisodes <= 0) return '';
      final skipped = s.skippedEpisodes > 0
          ? l10n.fileBrowser_skippedEpisodesSuffix(s.skippedEpisodes)
          : '';
      final tail = skipped + failedSuffix(s.failedEpisodes);
      return l10n.fileBrowser_episodeCountFormat(s.totalEpisodes, tail);
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
        final completedText = Text(
          l10n.fileBrowser_refreshCompleted(
              summary.isNotEmpty ? '\n$summary' : ''),
        );
        if (!state.indexTruncated) return completedText;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            completedText,
            const SizedBox(height: 8),
            Text(
              l10n.download_indexTruncatedWarning,
              style: const TextStyle(color: Colors.orange),
            ),
          ],
        );
      case DownloadStatus.cancelled:
        return Text(l10n.download_cancelledMessage);
      case DownloadStatus.error:
        return Text(
          l10n.common_errorPrefix(
              state.errorMessage ?? l10n.common_unknownError),
          style: const TextStyle(color: Colors.red),
        );
    }
  }
}
