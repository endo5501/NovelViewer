import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/bookmark/data/bookmark_repository.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/reading_context/providers/reading_context_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_position_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_state_provider.dart';
import 'package:novel_viewer/features/tts/providers/vacuum_lifecycle_provider.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';
import 'package:novel_viewer/shared/database/novel_data_database.dart';
import 'package:novel_viewer/shared/database/novel_data_database_provider.dart';
import 'package:path/path.dart' as p;

final _log = Logger('text_download');

/// Carries episode file renames made by a download over to everything that
/// knows an episode by its file name.
///
/// A download renames episode files when the zero-pad width or a title changes
/// (`9_x.txt` -> `09_x.txt`). Left alone, the reading progress, bookmarks, TTS
/// audio and LLM summary records keep the old name, and so does the open
/// episode — which then cannot be found in its own episode listing, so paging
/// stops and the last-read position is never restored.
class EpisodeRenamePropagator {
  EpisodeRenamePropagator(this._ref);

  final Ref _ref;

  /// Applies [renames] (old file name -> new file name) for the novel at
  /// [novelFolderPath].
  ///
  /// The order matters:
  /// 1. The per-folder stores are rekeyed, each on its own: one failing is
  ///    logged and does not stop the others, nor the download that asked.
  /// 2. Reading progress goes last among the stores, behind a flush of the
  ///    pending body position, and a position observed after that flush is
  ///    moved over to the new name. Positions carry the file name, and once
  ///    the row is rekeyed a save under the old name matches nothing.
  /// 3. Only then is the open episode rebased. The rebase makes the auto-save
  ///    listener upsert the new name, which keeps the body position only if
  ///    the row already carries that name.
  Future<void> propagate({
    required String novelFolderPath,
    required Map<String, String> renames,
  }) async {
    if (renames.isEmpty) return;
    // Defensive: the migration only pairs files of one episode with that
    // episode's canonical name, so no new name is another pair's old one. Were
    // it ever so, applying both would depend on their order.
    final targets = renames.values.toSet();
    final chained = renames.keys.where(targets.contains).toSet();
    if (chained.isNotEmpty) {
      _log.warning(
        'Skipping chained episode renames in $novelFolderPath: $chained',
      );
    }
    final applied = {
      for (final MapEntry(key: from, value: to) in renames.entries)
        if (!chained.contains(from)) from: to,
    };
    final pairs = [
      for (final MapEntry(key: from, value: to) in applied.entries)
        (from: from, to: to),
    ];

    // Opened only when the file is already there: the registry creates a
    // missing database, and a novel that never had a bookmark or TTS audio
    // must not gain an empty one.
    final folderKey = folderDbKey(novelFolderPath);
    if (_exists(novelFolderPath, NovelDataDatabase.databaseName)) {
      final db = await _ref.read(novelDataDatabaseProvider(folderKey)).database;
      await _attempt('bookmarks', novelFolderPath, () async {
        final repository = BookmarkRepository(db);
        for (final pair in pairs) {
          await repository.renameFileName(from: pair.from, to: pair.to);
        }
      });
      await _attempt('fact cache', novelFolderPath, () async {
        final repository = FactCacheRepository(db);
        for (final pair in pairs) {
          await repository.renameFileName(from: pair.from, to: pair.to);
        }
      });
      await _attempt('summary jump targets', novelFolderPath, () async {
        final repository = LlmSummaryRepository(db);
        for (final pair in pairs) {
          await repository.renameSourceFile(from: pair.from, to: pair.to);
        }
      });
    }
    if (_exists(novelFolderPath, 'tts_audio.db')) {
      await _attempt('TTS audio', novelFolderPath, () async {
        final repository = TtsAudioRepository(
          _ref.read(ttsAudioDatabaseProvider(folderKey)),
          onEpisodeDeleted: () =>
              _ref.read(vacuumLifecycleProvider).markDirty(novelFolderPath),
        );
        for (final pair in pairs) {
          await repository.renameFileName(from: pair.from, to: pair.to);
        }
      });
    }

    // Through the writer's queue, behind the pending position the flush hands
    // it and ahead of the auto-save the rebase below enqueues: every write to
    // the row is serialised there, so the order holds by construction rather
    // than by which async write happens to reach the database first.
    final writer = _ref.read(readingPositionWriterProvider);
    final novelId = p.basename(novelFolderPath);
    unawaited(writer.flush());
    await writer.enqueue(
      () => _attempt('reading progress', novelFolderPath, () async {
        final repository = _ref.read(readingProgressRepositoryProvider);
        for (final pair in pairs) {
          await repository.renameFileName(
            novelId: novelId,
            from: pair.from,
            to: pair.to,
          );
        }
      }),
    );

    // Anything observed while the stores were being rekeyed still names the
    // old file; it is moved over before the rebase flushes it.
    writer.renamePending(novelId, applied);
    _rebaseOpenEpisode(novelFolderPath, applied);

    invalidateEpisodeListings(_ref.invalidate);
    _ref.invalidate(bookmarksForCurrentNovelProvider);
    _ref.invalidate(bookmarkLineNumbersForFileProvider);
    _ref.invalidate(ttsAudioStateProvider);
    _ref.invalidate(llmSummaryHistoryProvider);
    // Holds snapshots, jump targets included, for as long as the app runs.
    _ref.invalidate(hoverPopupCacheProvider);
    _ref.read(readingProgressRevisionProvider.notifier).bump();
  }

  /// Points the open episode at its new name when it was one of [renames].
  ///
  /// A rebase, not a file open: nothing was opened, and counting it as one
  /// would close the drawer on a reader who merely started an update.
  void _rebaseOpenEpisode(String novelFolderPath, Map<String, String> renames) {
    final selected = _ref.read(selectedFileProvider);
    if (selected == null) return;
    if (!p.equals(p.dirname(selected.path), novelFolderPath)) return;
    final newName = renames[selected.name];
    if (newName == null) return;
    _ref
        .read(selectedFileProvider.notifier)
        .rebase(
          FileEntry(name: newName, path: p.join(novelFolderPath, newName)),
        );
  }

  bool _exists(String folder, String databaseName) =>
      File(p.join(folder, databaseName)).existsSync();

  Future<void> _attempt(
    String store,
    String novelFolderPath,
    Future<void> Function() rekey,
  ) async {
    try {
      await rekey();
    } catch (e, st) {
      _log.warning(
        'Failed to carry episode renames over to $store in $novelFolderPath',
        e,
        st,
      );
    }
  }
}

final episodeRenamePropagatorProvider = Provider<EpisodeRenamePropagator>(
  EpisodeRenamePropagator.new,
);
