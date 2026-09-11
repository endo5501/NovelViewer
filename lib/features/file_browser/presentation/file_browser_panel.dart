import 'dart:io' show FileSystemException;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/gestures/pointer_kinds.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/domain/novel_folder_classifier.dart';
import 'package:novel_viewer/features/file_browser/domain/move_destination.dart';
import 'package:novel_viewer/features/file_browser/domain/reading_progress_badge.dart';
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
///
/// Raised from the single-line 56.0 so a registered novel folder tile can show
/// a second line (the reading-progress bar) under its title without clipping.
/// File tiles share this extent and simply gain a little vertical breathing
/// room.
const double _kFileTileExtent = 64.0;

class _FileBrowserPanelState extends ConsumerState<FileBrowserPanel> {
  /// The file list's scroll controller, created by [_controllerForViewport] on
  /// the first build that has both a listing and a measured viewport.
  ///
  /// Deferring its creation is what lets the list open already sitting on the
  /// selected file. A closed [Drawer] unmounts its child, so in the narrow
  /// layout the whole panel is rebuilt from scratch every time the reader
  /// opens the file browser, and crossing the shell's layout breakpoint
  /// (rotating a tablet, resizing a window) does the same. The selection is
  /// already in place on such a remount, so it never transitions and the
  /// listener in [initState] never fires — the list would open at the top.
  /// Handing the controller its starting offset before the list is first laid
  /// out covers every one of those paths, without the panel having to know
  /// which one it is in and without a frame at the top first.
  ///
  /// Existing for the rest of the mount is also what keeps the placement to a
  /// single occasion: opening another folder while the panel stays mounted
  /// must not chase a selection carried over from the folder before it.
  ScrollController? _scrollController;

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
    _scrollController?.dispose();
    super.dispose();
  }

  /// The position of [file] in the flat item list, or null when the current
  /// listing does not contain it.
  ///
  /// Files render after subdirectories, so the folder count is the offset
  /// between a file's index and its row.
  int? _flatIndexOf(DirectoryContents contents, FileEntry file) {
    final fileIndex = contents.files.indexWhere((f) => f.path == file.path);
    if (fileIndex < 0) return null;
    return contents.subdirectories.length + fileIndex;
  }

  /// The scroll offset that puts row [flatIndex] in the middle of a viewport
  /// [viewportHeight] tall, kept within [maxScrollExtent].
  ///
  /// Rows either side of the target stay visible, which is what makes the
  /// neighbouring episodes reachable from where the list lands.
  double _centeredOffset({
    required int flatIndex,
    required double viewportHeight,
    required double maxScrollExtent,
  }) {
    final centered =
        flatIndex * _kFileTileExtent - (viewportHeight - _kFileTileExtent) / 2;
    return centered.clamp(0.0, maxScrollExtent);
  }

  /// The controller for a list of [itemCount] rows in a viewport
  /// [viewportHeight] tall, created on first use and kept for the rest of the
  /// mount.
  ///
  /// The first call is the one that places the list: it starts the controller
  /// on the selected file rather than at the top. A fixed [_kFileTileExtent]
  /// makes both the target offset and the maximum scroll extent computable
  /// from the row count alone, so the offset is known before the list has ever
  /// been laid out and no frame is composited at the top on the way there.
  ScrollController _controllerForViewport({
    required double viewportHeight,
    required int itemCount,
    required DirectoryContents contents,
    required FileEntry? selectedFile,
  }) {
    final existing = _scrollController;
    if (existing != null) return existing;

    var initialOffset = 0.0;
    if (selectedFile != null) {
      final flatIndex = _flatIndexOf(contents, selectedFile);
      if (flatIndex != null) {
        initialOffset = _centeredOffset(
          flatIndex: flatIndex,
          viewportHeight: viewportHeight,
          maxScrollExtent: math.max(
            0.0,
            itemCount * _kFileTileExtent - viewportHeight,
          ),
        );
      }
    }
    return _scrollController = ScrollController(
      initialScrollOffset: initialOffset,
    );
  }

  /// Animates [file] to the middle of the viewport after the current frame.
  void _scheduleScrollTo(FileEntry file) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _scrollController;
      if (!mounted || controller == null || !controller.hasClients) return;
      final contents = ref.read(directoryContentsProvider).value;
      if (contents == null) return;
      final flatIndex = _flatIndexOf(contents, file);
      if (flatIndex == null) return;
      controller.animateTo(
        _centeredOffset(
          flatIndex: flatIndex,
          viewportHeight: controller.position.viewportDimension,
          maxScrollExtent: controller.position.maxScrollExtent,
        ),
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
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.fileBrowser_selectFolderPrompt,
                  ),
                )
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
              onPressed: hasParent ? () => _navigateToParent(currentDir) : null,
              tooltip: AppLocalizations.of(
                context,
              )!.fileBrowser_goToParentFolder,
            ),
          if (currentDir != null)
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              onPressed: () => _showNewFolderDialog(context, currentDir),
              tooltip: AppLocalizations.of(
                context,
              )!.fileBrowser_newFolderTooltip,
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
        child: Text(
          AppLocalizations.of(context)!.common_errorPrefix(error.toString()),
        ),
      ),
      data: (contents) {
        if (contents.isEmpty) {
          return Center(
            child: Text(AppLocalizations.of(context)!.fileBrowser_noFilesFound),
          );
        }

        // The set of registered novel folder names lets us classify each
        // subdirectory as a novel folder vs an organizational folder at any
        // depth (see [isNovelFolder]).
        final novels = ref.watch(allNovelsProvider).value ?? const [];
        final novelFolderNames = <String>{for (final n in novels) n.folderName};
        final badges =
            ref.watch(readingProgressBadgesProvider).value ?? const {};
        final items = [
          ...contents.subdirectories.map((dir) {
            final isNovel = isNovelFolder(dir.name, novelFolderNames);
            return _buildDirectoryTile(
              context,
              dir,
              isNovel,
              isNovel ? badges[dir.name] : null,
            );
          }),
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

        // The viewport height decides where a centred row sits, so the
        // controller is created from inside a LayoutBuilder rather than in
        // initState. Only a build that reaches here creates it, which is what
        // leaves the placement to the first real listing: a panel mounted
        // while the directory is still loading returns the indicator above,
        // and an empty folder returns the message above.
        //
        // The controller is created even when nothing is selected, so that a
        // file tapped afterwards scrolls with the usual animation instead of
        // being overtaken by a placement meant for a remount.
        return LayoutBuilder(
          builder: (context, constraints) => ListView(
            controller: _controllerForViewport(
              viewportHeight: constraints.maxHeight,
              itemCount: items.length,
              contents: contents,
              selectedFile: selectedFile,
            ),
            itemExtent: _kFileTileExtent,
            children: items,
          ),
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
      title: Tooltip(
        message: file.name,
        child: Text(
          file.name,
          style: isSelected
              ? const TextStyle(fontWeight: FontWeight.w600)
              : null,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: switch (ttsStatus) {
        TtsEpisodeStatus.completed => const Icon(
          Icons.check_circle,
          color: Colors.green,
        ),
        TtsEpisodeStatus.partial || TtsEpisodeStatus.generating => const Icon(
          Icons.pie_chart,
          color: Colors.orange,
        ),
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
        border: Border(left: BorderSide(color: colorScheme.primary, width: 4)),
      ),
      child: Material(type: MaterialType.transparency, child: tile),
    );
  }

  Widget _buildDirectoryTile(
    BuildContext context,
    DirectoryEntry dir,
    bool isNovel,
    ReadingProgressBadge? badge,
  ) {
    final tile = ListTile(
      leading: Icon(isNovel ? Icons.menu_book : Icons.folder),
      title: Tooltip(
        message: dir.displayName,
        // Hover only. Tooltip's default touch trigger is a long press, and it
        // registers its own recognizer deeper in the tree than the gesture
        // detector below, so it would win the arena and swallow the context
        // menu over the title — which is most of the tile. Hovering is handled
        // by a MouseRegion and does not go through triggerMode, so the desktop
        // behaviour is unchanged.
        triggerMode: TooltipTriggerMode.manual,
        child: Text(
          dir.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      subtitle: badge == null ? null : _ReadingProgressBar(badge: badge),
      onTap: () {
        ref.read(currentDirectoryProvider.notifier).setDirectory(dir.path);
        ref.read(selectedFileProvider.notifier).clear();
      },
    );

    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showContextMenu(context, details.globalPosition, dir, isNovel);
      },
      // The same menu, reached without a secondary mouse button. Restricted to
      // the pointers that need it: a mouse held down past the long-press
      // deadline would otherwise open the menu instead of entering the folder,
      // and it can already reach the menu with its secondary button.
      child: GestureDetector(
        supportedDevices: kNoSecondaryButtonPointerKinds,
        onLongPressStart: (details) {
          _showContextMenu(context, details.globalPosition, dir, isNovel);
        },
        child: tile,
      ),
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
        child: Text(
          l10n.fileBrowser_deleteMenuItem,
          style: const TextStyle(color: Colors.red),
        ),
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

  Future<void> _showMoveDialog(BuildContext context, DirectoryEntry dir) async {
    final libraryPath = ref.read(libraryPathProvider);
    if (libraryPath == null) return;

    final novels = ref.read(allNovelsProvider).value ?? const [];
    final novelFolderNames = <String>{for (final n in novels) n.folderName};
    final service = ref.read(fileSystemServiceProvider);

    final List<String> orgPaths;
    try {
      orgPaths = await service.listOrganizationalFolderTree(
        libraryPath,
        novelFolderNames,
      );
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
      await releaseFolderDbHandles(
        dir.path,
        read: ref.read,
        invalidate: ref.invalidate,
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_directoryOpMessage(context, e))));
    }
  }

  void _showDeleteFolderConfirmation(BuildContext context, DirectoryEntry dir) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.fileBrowser_deleteFolderTitle),
        content: Text(
          l10n.fileBrowser_deleteFolderConfirmation(dir.displayName),
        ),
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
        await releaseFolderDbHandles(
          dir.path,
          read: ref.read,
          invalidate: ref.invalidate,
        );
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
        await releaseFolderDbHandles(
          dir.path,
          read: ref.read,
          invalidate: ref.invalidate,
        );
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
          content: Text(
            AppLocalizations.of(context)!.fileBrowser_downloadInProgressWarning,
          ),
        ),
      );
      return;
    }

    // Re-download into the novel folder's current physical parent so a novel
    // stored inside an organizational subfolder updates in place instead of
    // being duplicated at the library root. `dir.path` is the novel folder's
    // absolute path; its dirname is the parent directory.
    ref
        .read(downloadProvider.notifier)
        .refreshNovel(dir.name, parentPath: p.dirname(dir.path));

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RefreshProgressDialog(novelTitle: dir.displayName),
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
            content: Text(
              AppLocalizations.of(
                context,
              )!.fileBrowser_renameFailed(e.toString()),
            ),
          ),
        );
      }
    });
  }

  void _showDeleteConfirmation(BuildContext context, DirectoryEntry dir) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.fileBrowser_deleteNovelTitle),
        content: Text(
          AppLocalizations.of(
            context,
          )!.fileBrowser_deleteNovelConfirmation(dir.displayName),
        ),
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
        if (selectedFile != null && p.isWithin(dir.path, selectedFile.path)) {
          ref.read(selectedFileProvider.notifier).clear();
        }
        final deleteService = await ref.read(novelDeleteServiceProvider.future);
        await deleteService.delete(dir.name, dir.path);
        ref.invalidate(allNovelsProvider);
        ref.invalidate(directoryContentsProvider);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.fileBrowser_deleteFailed(e.toString()),
            ),
          ),
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

/// A compact reading-progress indicator shown under a novel folder's title:
/// a thin bar plus a small `read / total` label. Both numbers come from
/// [ReadingProgressBadge] (denominator = `episode_count`, numerator = current
/// position; 0 = unread).
class _ReadingProgressBar extends StatelessWidget {
  final ReadingProgressBadge badge;

  const _ReadingProgressBar({required this.badge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: badge.fraction,
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${badge.read} / ${badge.total}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _RefreshProgressDialog extends ConsumerWidget {
  final String novelTitle;

  const _RefreshProgressDialog({required this.novelTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);

    return AlertDialog(
      title: Text(
        AppLocalizations.of(
          context,
        )!.fileBrowser_refreshProgressTitle(novelTitle),
      ),
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
            child: Text(AppLocalizations.of(context)!.common_closeButton),
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
              Text('${state.currentEpisode} / ${episodeSummary(state)}'),
          ],
        );
      case DownloadStatus.completed:
        final summary = episodeSummary(state);
        final completedText = Text(
          l10n.fileBrowser_refreshCompleted(
            summary.isNotEmpty ? '\n$summary' : '',
          ),
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
            state.errorMessage ?? l10n.common_unknownError,
          ),
          style: const TextStyle(color: Colors.red),
        );
    }
  }
}
