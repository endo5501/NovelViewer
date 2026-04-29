import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_adapters.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_repository.dart';
import 'package:novel_viewer/features/tts/data/tts_isolate.dart';
import 'package:novel_viewer/features/tts/data/tts_streaming_controller.dart';
import 'package:novel_viewer/features/tts/domain/tts_engine_config.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode.dart';
import 'package:novel_viewer/features/tts/presentation/tts_edit_dialog.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_state_provider.dart';
import 'package:novel_viewer/features/tts/providers/vacuum_lifecycle_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_export_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/utils/temp_directory_utils.dart';

/// TTS control buttons (play / pause / stop / edit / export / delete) overlaid
/// on the text viewer. Owns the streaming controller lifetime, the
/// `(TtsAudioState × TtsPlaybackState)` state-machine switch, and the dialogs
/// it launches (TTS edit, delete confirmation). The bar renders nothing when
/// `ttsModelDir` is empty.
class TtsControlsBar extends ConsumerStatefulWidget {
  const TtsControlsBar({super.key, required this.content});

  final String content;

  @override
  ConsumerState<TtsControlsBar> createState() => _TtsControlsBarState();
}

class _TtsControlsBarState extends ConsumerState<TtsControlsBar>
    with WidgetsBindingObserver {
  TtsStreamingController? _streamingController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Stop active streaming when the user switches files.
    ref.listenManual(selectedFileProvider, (prev, next) {
      if (prev?.path != next?.path && _streamingController != null) {
        _stopStreaming();
      }
    });
    // Stop active streaming when the renderer requests it (e.g. manual scroll
    // during playback).
    ref.listenManual(ttsStopRequestProvider, (prev, next) {
      if (prev != null && next != prev && _streamingController != null) {
        _stopStreaming();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamingController?.stop();
    _streamingController = null;
    super.dispose();
  }

  /// Clean up TTS native resources before app exit to prevent crash.
  ///
  /// The TTS engine uses Metal GPU resources via ggml. If the process exits
  /// while Metal initialization is still running on a background thread,
  /// the C++ static destructors race with the init thread and abort.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await _stopStreaming();
    return AppExitResponse.exit;
  }

  Future<void> _startStreaming() async {
    final folderPath = ref.read(currentDirectoryProvider);
    final selectedFile = ref.read(selectedFileProvider);
    final fileName = selectedFile?.name;
    final engineType = ref.read(ttsEngineTypeProvider);

    final config = TtsEngineConfig.resolveFromRef(ref, engineType);

    if (folderPath == null ||
        selectedFile == null ||
        fileName == null ||
        config.modelDir.isEmpty) {
      return;
    }

    // Use selectedFile.path verbatim so it matches the family key the build
    // watches via `ttsAudioStateProvider(selectedFile.path)`. Building the
    // path from `'$folderPath/$fileName'` here mixes separators on Windows
    // (`D:\foo/bar.txt`), which makes the active-streaming key never match
    // the watched key, so the UI never flips to the "generating" state and
    // the stop button stays hidden.
    final filePath = selectedFile.path;
    ref.read(activeStreamingFileProvider.notifier).set(filePath);
    ref.invalidate(ttsAudioStateProvider(filePath));
    ref
        .read(ttsGenerationProgressProvider.notifier)
        .set(const TtsGenerationProgress(current: 0, total: 0));

    final db = ref.read(ttsAudioDatabaseProvider(folderPath));
    final lifecycle = ref.read(vacuumLifecycleProvider);
    final repo = TtsAudioRepository(
      db,
      onEpisodeDeleted: () => lifecycle.markDirty(folderPath),
    );
    final dictDb = ref.read(ttsDictionaryDatabaseProvider(folderPath));
    final dictRepo = TtsDictionaryRepository(dictDb);
    final isolate = TtsIsolate();
    final tempDir = await ensureTemporaryDirectory();

    final controller = TtsStreamingController(
      read: ref.read,
      ttsIsolate: isolate,
      audioPlayer: JustAudioPlayer(),
      repository: repo,
      tempDirPath: tempDir.path,
      dictionaryRepository: dictRepo,
    );
    _streamingController = controller;

    final selectedText = ref.read(selectedTextProvider);
    int? startOffset;
    if (selectedText != null && selectedText.isNotEmpty) {
      final index = widget.content.indexOf(selectedText);
      if (index >= 0) startOffset = index;
    }

    final voiceService = ref.read(voiceReferenceServiceProvider);

    try {
      await controller.start(
        text: widget.content,
        fileName: fileName,
        config: config,
        startOffset: startOffset,
        resolveRefWavPath: voiceService?.resolveVoiceFilePath,
      );
    } finally {
      _streamingController = null;
      ref.read(activeStreamingFileProvider.notifier).set(null);
      if (mounted) {
        ref.invalidate(ttsAudioStateProvider(filePath));
        ref.invalidate(directoryContentsProvider);
      }
    }
  }

  Future<void> _stopStreaming() async {
    try {
      await _streamingController?.stop();
    } finally {
      _streamingController = null;
      ref.read(activeStreamingFileProvider.notifier).set(null);

      // Defensively clear playback state regardless of stop() success.
      if (mounted) {
        ref
            .read(ttsPlaybackStateProvider.notifier)
            .set(TtsPlaybackState.stopped);
        ref.read(ttsHighlightRangeProvider.notifier).set(null);
        ref
            .read(ttsGenerationProgressProvider.notifier)
            .set(TtsGenerationProgress.zero);
        final selectedPath = ref.read(selectedFileProvider)?.path;
        if (selectedPath != null) {
          ref.invalidate(ttsAudioStateProvider(selectedPath));
        }
      }
    }
  }

  Future<void> _pausePlayback() async {
    await _streamingController?.pause();
  }

  Future<void> _resumePlayback() async {
    await _streamingController?.resume();
  }

  /// Looks up the episode for the currently selected file and runs [action]
  /// with the repository and episode. Returns null if no directory/file is
  /// selected or no episode exists.
  Future<T?> _withEpisodeRepo<T>(
    Future<T?> Function(TtsAudioRepository repo, TtsEpisode episode) action,
  ) async {
    final folderPath = ref.read(currentDirectoryProvider);
    final fileName = ref.read(selectedFileProvider)?.name;
    if (folderPath == null || fileName == null) return null;

    final db = ref.read(ttsAudioDatabaseProvider(folderPath));
    final lifecycle = ref.read(vacuumLifecycleProvider);
    final repo = TtsAudioRepository(
      db,
      onEpisodeDeleted: () => lifecycle.markDirty(folderPath),
    );
    final episode = await repo.findEpisodeByFileName(fileName);
    if (episode == null) return null;
    return action(repo, episode);
  }

  Future<void> _deleteAudio() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.textViewer_deleteAudioTitle),
          content: Text(l10n.textViewer_deleteAudioConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.common_cancelButton),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.common_deleteButton),
            ),
          ],
        );
      },
    );
    if (!mounted || confirm != true) return;

    await _withEpisodeRepo((repo, episode) async {
      await repo.deleteEpisode(episode.id);
      return null;
    });

    if (!mounted) return;
    final selectedPath = ref.read(selectedFileProvider)?.path;
    if (selectedPath != null) {
      ref.invalidate(ttsAudioStateProvider(selectedPath));
    }
    ref.invalidate(directoryContentsProvider);
  }

  Future<void> _exportAudio() async {
    final fileName = ref.read(selectedFileProvider)?.name;
    if (fileName == null) return;

    try {
      final exported = await _withEpisodeRepo((repo, episode) async {
        return exportEpisodeToMp3(
          stateNotifier: ref.read(ttsExportStateProvider.notifier),
          progressNotifier: ref.read(ttsExportProgressProvider.notifier),
          repository: repo,
          episodeId: episode.id,
          episodeFileName: fileName,
          sampleRate: episode.sampleRate,
        );
      });

      if (!mounted || exported != true) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.textViewer_exportCompleted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .textViewer_exportError(e.toString()))),
      );
    }
  }

  Future<void> _openEditDialog() async {
    final folderPath = ref.read(currentDirectoryProvider);
    final fileName = ref.read(selectedFileProvider)?.name;
    if (folderPath == null || fileName == null) return;

    await TtsEditDialog.show(
      context,
      folderPath: folderPath,
      fileName: fileName,
      content: widget.content,
    );

    // Refresh audio state and file browser TTS icons after dialog closes
    if (mounted) {
      ref.invalidate(directoryContentsProvider);
      final selectedPath = ref.read(selectedFileProvider)?.path;
      if (selectedPath != null) {
        ref.invalidate(ttsAudioStateProvider(selectedPath));
      }
    }
  }

  static const _waitingSpinner = Padding(
    padding: EdgeInsets.only(right: 8),
    child: SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );

  Widget _buildGenerationProgress() {
    final progress = ref.watch(ttsGenerationProgressProvider);
    final fraction =
        progress.total > 0 ? progress.current / progress.total : 0.0;
    return SizedBox(
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          LinearProgressIndicator(value: fraction),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(context)!.textViewer_generationProgressFormat(
                progress.current, progress.total),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  FloatingActionButton _editButton() {
    return FloatingActionButton.small(
      onPressed: _openEditDialog,
      tooltip: AppLocalizations.of(context)!.textViewer_editTtsTooltip,
      child: const Icon(Icons.edit_note),
    );
  }

  FloatingActionButton _generateButton() {
    return FloatingActionButton.small(
      onPressed: _startStreaming,
      tooltip: AppLocalizations.of(context)!.textViewer_generateTtsTooltip,
      child: const Icon(Icons.record_voice_over),
    );
  }

  FloatingActionButton _playButton() {
    return FloatingActionButton.small(
      onPressed: _startStreaming,
      tooltip: AppLocalizations.of(context)!.textViewer_playTooltip,
      child: const Icon(Icons.play_arrow),
    );
  }

  FloatingActionButton _pauseButton() {
    return FloatingActionButton.small(
      onPressed: _pausePlayback,
      tooltip: AppLocalizations.of(context)!.textViewer_pauseTooltip,
      child: const Icon(Icons.pause),
    );
  }

  FloatingActionButton _resumeButton() {
    return FloatingActionButton.small(
      onPressed: _resumePlayback,
      tooltip: AppLocalizations.of(context)!.textViewer_resumeTooltip,
      child: const Icon(Icons.play_arrow),
    );
  }

  FloatingActionButton _stopButton() {
    return FloatingActionButton.small(
      onPressed: _stopStreaming,
      tooltip: AppLocalizations.of(context)!.textViewer_stopTooltip,
      child: const Icon(Icons.stop),
    );
  }

  FloatingActionButton _cancelButton() {
    return FloatingActionButton.small(
      onPressed: _stopStreaming,
      tooltip: AppLocalizations.of(context)!.textViewer_cancelTooltip,
      child: const Icon(Icons.close),
    );
  }

  FloatingActionButton _deleteButton() {
    return FloatingActionButton.small(
      onPressed: _deleteAudio,
      tooltip: AppLocalizations.of(context)!.textViewer_deleteAudioTooltip,
      child: const Icon(Icons.delete_outline),
    );
  }

  Widget _exportButtonOrProgress() {
    final exportState = ref.watch(ttsExportStateProvider);
    if (exportState != TtsExportState.exporting) {
      return FloatingActionButton.small(
        onPressed: _exportAudio,
        tooltip: AppLocalizations.of(context)!.textViewer_exportMp3Tooltip,
        child: const Icon(Icons.download),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 20,
        height: 20,
        child: Consumer(
          builder: (context, ref, _) {
            final progress = ref.watch(ttsExportProgressProvider);
            return CircularProgressIndicator(
              value: progress.total > 0
                  ? progress.current / progress.total
                  : null,
              strokeWidth: 2,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ttsModelDir = ref.watch(ttsModelDirProvider);
    if (ttsModelDir.isEmpty) return const SizedBox.shrink();

    final selectedFile = ref.watch(selectedFileProvider);
    final audioStateAsync = selectedFile == null
        ? const AsyncValue<TtsAudioState>.data(TtsAudioState.none)
        : ref.watch(ttsAudioStateProvider(selectedFile.path));
    final audioState = audioStateAsync.value ?? TtsAudioState.none;
    final playbackState = ref.watch(ttsPlaybackStateProvider);

    return _buildButtons(audioState, playbackState);
  }

  Widget _buildButtons(TtsAudioState audio, TtsPlaybackState playback) {
    return switch ((audio, playback)) {
      (TtsAudioState.none, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _editButton(),
            const SizedBox(width: 8),
            _generateButton(),
          ],
        ),
      (TtsAudioState.generating, TtsPlaybackState.stopped) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGenerationProgress(),
            const SizedBox(width: 8),
            _cancelButton(),
          ],
        ),
      (TtsAudioState.generating, TtsPlaybackState.playing) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGenerationProgress(),
            const SizedBox(width: 8),
            _pauseButton(),
            const SizedBox(width: 8),
            _stopButton(),
          ],
        ),
      (TtsAudioState.generating, TtsPlaybackState.waiting) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _waitingSpinner,
            _buildGenerationProgress(),
            const SizedBox(width: 8),
            _pauseButton(),
            const SizedBox(width: 8),
            _stopButton(),
          ],
        ),
      (TtsAudioState.generating, TtsPlaybackState.paused) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGenerationProgress(),
            const SizedBox(width: 8),
            _resumeButton(),
            const SizedBox(width: 8),
            _stopButton(),
          ],
        ),
      (TtsAudioState.ready, TtsPlaybackState.playing) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pauseButton(),
            const SizedBox(width: 8),
            _stopButton(),
          ],
        ),
      (TtsAudioState.ready, TtsPlaybackState.waiting) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _waitingSpinner,
            _pauseButton(),
            const SizedBox(width: 8),
            _stopButton(),
          ],
        ),
      (TtsAudioState.ready, TtsPlaybackState.paused) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _resumeButton(),
            const SizedBox(width: 8),
            _stopButton(),
          ],
        ),
      (TtsAudioState.ready, TtsPlaybackState.stopped) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _editButton(),
            const SizedBox(width: 8),
            _playButton(),
            const SizedBox(width: 8),
            _exportButtonOrProgress(),
            const SizedBox(width: 8),
            _deleteButton(),
          ],
        ),
    };
  }
}
