import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_position_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';

import 'progress_sync_entry_providers.dart';

/// Carries out the reader's answer to a [SyncPromptRequest].
abstract class SyncPromptActions {
  /// [move] opens the other device's position; either way the record counts
  /// as answered, so the same record is not asked about again.
  Future<void> answer(SyncPromptRequest request, {required bool move});
}

class _SyncPromptActions implements SyncPromptActions {
  final Ref _ref;

  _SyncPromptActions(this._ref);

  @override
  Future<void> answer(SyncPromptRequest request, {required bool move}) async {
    final entry = _ref.read(progressSyncEntryProvider);
    if (entry == null) return;
    try {
      if (move) await _move(entry, request);
      await entry.markHandled(request.novelId, request.remote.record.readAt);
    } catch (e, st) {
      Logger('progress_sync').warning(
        'Failed to apply the answer for ${request.novelId}',
        e,
        st,
      );
    }
  }

  Future<void> _move(ProgressSyncEntry entry, SyncPromptRequest request) async {
    // Positions still waiting for the open file go first, so they cannot
    // land on top of the position being moved to.
    await _ref.read(readingPositionWriterProvider).flush();
    await entry.adopt(
      progress: _ref.read(readingProgressRepositoryProvider),
      remote: request.remote,
      fileName: request.fileName,
    );
    if (_ref.read(currentDirectoryProvider) != request.directory) return;

    final selected = _ref.read(selectedFileProvider);
    if (selected != null &&
        p.equals(selected.path, p.join(request.directory, request.fileName))) {
      _ref.read(readingPositionRestoreRequestProvider.notifier).request();
      return;
    }
    _ref.read(selectedFileProvider.notifier).selectFile(await _target(request));
  }

  Future<FileEntry> _target(SyncPromptRequest request) async {
    final contents = await _ref.read(directoryContentsProvider.future);
    for (final file in contents.files) {
      if (p.equals(file.name, request.fileName)) return file;
    }
    return FileEntry(
      name: request.fileName,
      path: p.join(request.directory, request.fileName),
    );
  }
}

final syncPromptActionsProvider = Provider<SyncPromptActions>(
  _SyncPromptActions.new,
);
