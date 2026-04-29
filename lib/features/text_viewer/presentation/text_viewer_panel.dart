import 'dart:math' show min, max;
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/shared/utils/temp_directory_utils.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/parsed_segments_cache.dart';
import 'package:novel_viewer/features/text_viewer/data/ruby_text_parser.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_adapters.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_repository.dart';
import 'package:novel_viewer/features/tts/data/tts_isolate.dart';
import 'package:novel_viewer/features/tts/data/tts_streaming_controller.dart';
import 'package:novel_viewer/features/tts/domain/tts_engine_config.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode.dart';
import 'package:novel_viewer/features/tts/presentation/dictionary_context_menu.dart';
import 'package:novel_viewer/features/tts/presentation/tts_dictionary_dialog.dart';
import 'package:novel_viewer/features/tts/presentation/tts_edit_dialog.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_state_provider.dart';
import 'package:novel_viewer/features/tts/providers/vacuum_lifecycle_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_export_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class TextViewerPanel extends ConsumerStatefulWidget {
  const TextViewerPanel({super.key});

  @override
  ConsumerState<TextViewerPanel> createState() => _TextViewerPanelState();
}

class _TextViewerPanelState extends ConsumerState<TextViewerPanel>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final ParsedSegmentsCache _segmentsCache = ParsedSegmentsCache();
  String? _lastScrollKey;
  String? _lastViewedFilePath;
  bool _isTtsScrolling = false;

  TtsStreamingController? _streamingController;
  String? _previousSelectedPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_updateCurrentViewLine);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamingController?.stop();
    _streamingController = null;
    _scrollController.dispose();
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

  Future<void> _onSelectedFileChanged() async {
    final selectedPath = ref.read(selectedFileProvider)?.path;
    if (_previousSelectedPath == selectedPath) return;
    _previousSelectedPath = selectedPath;
    if (_streamingController != null) {
      await _stopStreaming();
    }
  }

  Future<void> _startStreaming(String content) async {
    final folderPath = ref.read(currentDirectoryProvider);
    final fileName = ref.read(selectedFileProvider)?.name;
    final engineType = ref.read(ttsEngineTypeProvider);

    final config = TtsEngineConfig.resolveFromRef(ref, engineType);

    if (folderPath == null || fileName == null || config.modelDir.isEmpty) {
      return;
    }

    final filePath = '$folderPath/$fileName';
    ref.read(activeStreamingFileProvider.notifier).set(filePath);
    ref.invalidate(ttsAudioStateProvider(filePath));
    ref.read(ttsGenerationProgressProvider.notifier)
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
    final providerContainer = ProviderScope.containerOf(context);
    final tempDir = await ensureTemporaryDirectory();

    final controller = TtsStreamingController(
      ref: providerContainer,
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
      final index = content.indexOf(selectedText);
      if (index >= 0) startOffset = index;
    }

    final voiceService = ref.read(voiceReferenceServiceProvider);

    try {
      await controller.start(
        text: content,
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
        ref.read(ttsPlaybackStateProvider.notifier).set(
            TtsPlaybackState.stopped);
        ref.read(ttsHighlightRangeProvider.notifier).set(null);
        ref.read(ttsGenerationProgressProvider.notifier)
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

  void _showVerticalContextMenu(
      BuildContext context, Offset position, String selectedText) {
    final l10n = AppLocalizations.of(context)!;
    final renderObject =
        Overlay.maybeOf(context)?.context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final overlay = renderObject;
    showMenu<_ContextMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _ContextMenuAction.copy,
          child: Text(l10n.contextMenu_copy),
        ),
        PopupMenuItem(
          value: _ContextMenuAction.addToDictionary,
          child: Text(l10n.contextMenu_addToDictionary),
        ),
      ],
    ).then((value) {
      if (value == null || !mounted) return;
      switch (value) {
        case _ContextMenuAction.copy:
          Clipboard.setData(ClipboardData(text: selectedText));
        case _ContextMenuAction.addToDictionary:
          _openDictionaryDialog(selectedText);
      }
    });
  }

  void _openDictionaryDialog(String selectedText) {
    final folderPath = ref.read(currentDirectoryProvider);
    if (folderPath == null) return;
    final dictDb = ref.read(ttsDictionaryDatabaseProvider(folderPath));
    final dictRepo = TtsDictionaryRepository(dictDb);
    TtsDictionaryDialog.show(
      context,
      repository: dictRepo,
      initialSurface: selectedText,
    );
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
        SnackBar(content: Text(AppLocalizations.of(context)!.textViewer_exportCompleted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.textViewer_exportError(e.toString()))),
      );
    }
  }

  Future<void> _openEditDialog(String content) async {
    final folderPath = ref.read(currentDirectoryProvider);
    final fileName = ref.read(selectedFileProvider)?.name;
    if (folderPath == null || fileName == null) return;

    await TtsEditDialog.show(
      context,
      folderPath: folderPath,
      fileName: fileName,
      content: content,
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

  Widget _buildGenerationProgress(double fraction, TtsGenerationProgress progress) {
    return SizedBox(
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          LinearProgressIndicator(value: fraction),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(context)!.textViewer_generationProgressFormat(progress.current, progress.total),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static const _waitingSpinner = Padding(
    padding: EdgeInsets.only(right: 8),
    child: SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );

  Widget _buildTtsControls(
      TtsAudioState audioState, TtsPlaybackState playbackState, String content) {
    final isWaiting = playbackState == TtsPlaybackState.waiting;
    final isPlaying = playbackState == TtsPlaybackState.playing || isWaiting;
    final isPaused = playbackState == TtsPlaybackState.paused;

    switch (audioState) {
      case TtsAudioState.none:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              onPressed: () => _openEditDialog(content),
              tooltip: AppLocalizations.of(context)!.textViewer_editTtsTooltip,
              child: const Icon(Icons.edit_note),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: () => _startStreaming(content),
              tooltip: AppLocalizations.of(context)!.textViewer_generateTtsTooltip,
              child: const Icon(Icons.record_voice_over),
            ),
          ],
        );

      case TtsAudioState.generating:
        final progress = ref.watch(ttsGenerationProgressProvider);
        final fraction =
            progress.total > 0 ? progress.current / progress.total : 0.0;
        final progressWidget = _buildGenerationProgress(fraction, progress);

        if (isPlaying) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWaiting) _waitingSpinner,
              progressWidget,
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _pausePlayback,
                tooltip: AppLocalizations.of(context)!.textViewer_pauseTooltip,
                child: const Icon(Icons.pause),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _stopStreaming,
                tooltip: AppLocalizations.of(context)!.textViewer_stopTooltip,
                child: const Icon(Icons.stop),
              ),
            ],
          );
        } else if (isPaused) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              progressWidget,
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _resumePlayback,
                tooltip: AppLocalizations.of(context)!.textViewer_resumeTooltip,
                child: const Icon(Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _stopStreaming,
                tooltip: AppLocalizations.of(context)!.textViewer_stopTooltip,
                child: const Icon(Icons.stop),
              ),
            ],
          );
        } else {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              progressWidget,
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _stopStreaming,
                tooltip: AppLocalizations.of(context)!.textViewer_cancelTooltip,
                child: const Icon(Icons.close),
              ),
            ],
          );
        }

      case TtsAudioState.ready:
        if (isPlaying) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWaiting) _waitingSpinner,
              FloatingActionButton.small(
                onPressed: _pausePlayback,
                tooltip: AppLocalizations.of(context)!.textViewer_pauseTooltip,
                child: const Icon(Icons.pause),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _stopStreaming,
                tooltip: AppLocalizations.of(context)!.textViewer_stopTooltip,
                child: const Icon(Icons.stop),
              ),
            ],
          );
        } else if (isPaused) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                onPressed: _resumePlayback,
                tooltip: AppLocalizations.of(context)!.textViewer_resumeTooltip,
                child: const Icon(Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _stopStreaming,
                tooltip: AppLocalizations.of(context)!.textViewer_stopTooltip,
                child: const Icon(Icons.stop),
              ),
            ],
          );
        } else {
          final exportState = ref.watch(ttsExportStateProvider);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                onPressed: () => _openEditDialog(content),
                tooltip: AppLocalizations.of(context)!.textViewer_editTtsTooltip,
                child: const Icon(Icons.edit_note),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: () => _startStreaming(content),
                tooltip: AppLocalizations.of(context)!.textViewer_playTooltip,
                child: const Icon(Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              if (exportState == TtsExportState.exporting)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final progress =
                            ref.watch(ttsExportProgressProvider);
                        return CircularProgressIndicator(
                          value: progress.total > 0
                              ? progress.current / progress.total
                              : null,
                          strokeWidth: 2,
                        );
                      },
                    ),
                  ),
                )
              else
                FloatingActionButton.small(
                  onPressed: _exportAudio,
                  tooltip: AppLocalizations.of(context)!.textViewer_exportMp3Tooltip,
                  child: const Icon(Icons.download),
                ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _deleteAudio,
                tooltip: AppLocalizations.of(context)!.textViewer_deleteAudioTooltip,
                child: const Icon(Icons.delete_outline),
              ),
            ],
          );
        }
    }
  }

  Widget _withTtsControls(Widget child, String ttsModelDir,
      TtsAudioState audioState, TtsPlaybackState playbackState, String content) {
    if (ttsModelDir.isEmpty) return child;
    return Stack(
      children: [
        child,
        Positioned(
          right: 8,
          bottom: 8,
          child: _buildTtsControls(audioState, playbackState, content),
        ),
      ],
    );
  }

  void _scrollToTtsHighlight(
      String content, TextRange range, TextStyle? textStyle) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final textBefore = content.substring(
          0, range.start.clamp(0, content.length));
      final lineNumber = '\n'.allMatches(textBefore).length;

      final lineHeight = _computeLineHeight(textStyle);
      final maxOffset = _scrollController.position.maxScrollExtent;
      final clampedOffset = (lineNumber * lineHeight).clamp(0.0, maxOffset);

      _isTtsScrolling = true;
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      ).then((_) {
        _isTtsScrolling = false;
      });
    });
  }

  double _computeLineHeight(TextStyle? textStyle) {
    final fs = textStyle?.fontSize ?? 14.0;
    return (textStyle?.height ?? 1.5) * fs;
  }

  double _lineNumberToOffset(int lineNumber, TextStyle? textStyle) {
    return (lineNumber - 1) * _computeLineHeight(textStyle);
  }

  int _lastReportedViewLine = 0;

  void _updateCurrentViewLine() {
    if (!mounted || !_scrollController.hasClients) return;
    final fontSize = ref.read(fontSizeProvider);
    final fontFamily = ref.read(fontFamilyProvider);
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: fontSize,
          fontFamily: fontFamily.effectiveFontFamilyName,
        );
    final lineHeight = _computeLineHeight(textStyle);
    if (lineHeight <= 0) return;
    final lineNumber = (_scrollController.offset / lineHeight).floor() + 1;
    if (lineNumber != _lastReportedViewLine) {
      _lastReportedViewLine = lineNumber;
      ref.read(currentViewLineProvider.notifier).set(lineNumber);
    }
  }

  void _scrollToLineNumber(int lineNumber, TextStyle? textStyle) {
    if (!mounted || !_scrollController.hasClients) return;

    final maxOffset = _scrollController.position.maxScrollExtent;
    final clampedOffset = _lineNumberToOffset(lineNumber, textStyle).clamp(0.0, maxOffset);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(fileContentProvider);
    final selectedFile = ref.watch(selectedFileProvider);
    final searchMatch = ref.watch(selectedSearchMatchProvider);
    final displayMode = ref.watch(displayModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final fontFamily = ref.watch(fontFamilyProvider);

    final activeMatch = searchMatch != null &&
            selectedFile?.path == searchMatch.filePath
        ? searchMatch
        : null;

    // Reset current view line when file changes
    if (selectedFile?.path != _lastViewedFilePath) {
      _lastViewedFilePath = selectedFile?.path;
      _lastScrollKey = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(currentViewLineProvider.notifier).set(1);
          _lastReportedViewLine = 1;
        }
      });
    }

    return contentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(AppLocalizations.of(context)!.common_errorPrefix(error.toString()))),
      data: (content) {
        if (content == null) {
          return Center(
            child: Text(AppLocalizations.of(context)!.textViewer_selectFilePrompt),
          );
        }

        final ttsModelDir = ref.watch(ttsModelDirProvider);
        final audioStateAsync = selectedFile == null
            ? const AsyncValue<TtsAudioState>.data(TtsAudioState.none)
            : ref.watch(ttsAudioStateProvider(selectedFile.path));
        final audioState =
            audioStateAsync.value ?? TtsAudioState.none;
        final playbackState = ref.watch(ttsPlaybackStateProvider);
        final ttsHighlightRange = ref.watch(ttsHighlightRangeProvider);

        // Stop active streaming when the selection changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onSelectedFileChanged();
        });

        final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: fontSize,
              fontFamily: fontFamily.effectiveFontFamilyName,
            );
        final segments = _segmentsCache.getSegments(content);

        // Handle bookmark jump
        final bookmarkJumpLine = ref.watch(bookmarkJumpLineProvider);
        final targetLineNumber = activeMatch?.lineNumber ?? bookmarkJumpLine;

        // Bookmark indicators (shared between modes)
        final bookmarkLines =
            ref.watch(bookmarkLineNumbersForFileProvider).value ?? [];

        if (displayMode == TextDisplayMode.vertical) {
          // Clear bookmark jump after consuming in vertical mode
          if (bookmarkJumpLine != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) ref.read(bookmarkJumpLineProvider.notifier).clear();
            });
          }
          final columnSpacing = ref.watch(columnSpacingProvider);
          return _withTtsControls(
            VerticalTextViewer(
              segments: segments,
              baseStyle: textStyle,
              query: activeMatch?.query,
              targetLineNumber: targetLineNumber,
              ttsHighlightStart: ttsHighlightRange?.start,
              ttsHighlightEnd: ttsHighlightRange?.end,
              columnSpacing: columnSpacing,
              bookmarkLineNumbers: bookmarkLines,
              onPageLineChanged: (lineNumber) {
                ref.read(currentViewLineProvider.notifier).set(lineNumber);
              },
              onSelectionChanged: (text) {
                ref.read(selectedTextProvider.notifier).setText(text);
              },
              onContextMenu: (position, selectedText) {
                _showVerticalContextMenu(context, position, selectedText);
              },
            ),
            ttsModelDir,
            audioState,
            playbackState,
            content,
          );
        }

        // Horizontal mode
        final textSpan = buildRubyTextSpans(
          segments,
          textStyle,
          activeMatch?.query,
          ttsHighlightRange: ttsHighlightRange,
          brightness: Theme.of(context).brightness,
        );

        if (activeMatch != null) {
          final scrollKey =
              '${activeMatch.filePath}:${activeMatch.lineNumber}:${activeMatch.query}';
          if (scrollKey != _lastScrollKey) {
            _lastScrollKey = scrollKey;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToLineNumber(activeMatch.lineNumber, textStyle);
            });
          }
        } else if (bookmarkJumpLine != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scrollToLineNumber(bookmarkJumpLine, textStyle);
              ref.read(bookmarkJumpLineProvider.notifier).clear();
            }
          });
        }

        // Auto-scroll for TTS highlight
        if (ttsHighlightRange != null) {
          _scrollToTtsHighlight(content, ttsHighlightRange, textStyle);
        }

        return _withTtsControls(
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (!_isTtsScrolling &&
                  notification is ScrollStartNotification &&
                  notification.dragDetails != null &&
                  playbackState == TtsPlaybackState.playing) {
                _stopStreaming();
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                        left: bookmarkLines.isEmpty ? 0 : 20),
                    child: SelectableText.rich(
                      textSpan,
                      onSelectionChanged: (selection, cause) {
                        final start = min(selection.start, selection.end);
                        final end = max(selection.start, selection.end);
                        final selectedText =
                            extractSelectedText(start, end, segments);
                        ref.read(selectedTextProvider.notifier).setText(
                              selectedText.isEmpty ? null : selectedText,
                            );
                      },
                      contextMenuBuilder: (menuContext, editableTextState) {
                        return buildDictionaryContextMenu(
                          context,
                          editableTextState,
                          onAddToDictionary: _openDictionaryDialog,
                        );
                      },
                    ),
                  ),
                  for (final line in bookmarkLines)
                    Positioned(
                      left: 0,
                      top: _lineNumberToOffset(line, textStyle),
                      child: Icon(
                        Icons.bookmark,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          ttsModelDir,
          audioState,
          playbackState,
          content,
        );
      },
    );
  }
}

enum _ContextMenuAction { copy, addToDictionary }
