import 'dart:math' show min, max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/data/search_models.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/parsed_segments_cache.dart';
import 'package:novel_viewer/features/text_viewer/data/ruby_text_parser.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_adapters.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:novel_viewer/features/tts/data/tts_generation_controller.dart';
import 'package:novel_viewer/features/tts/data/tts_isolate.dart';
import 'package:novel_viewer/features/tts/data/tts_stored_player_controller.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';

class TextViewerPanel extends ConsumerStatefulWidget {
  const TextViewerPanel({super.key});

  @override
  ConsumerState<TextViewerPanel> createState() => _TextViewerPanelState();
}

class _TextViewerPanelState extends ConsumerState<TextViewerPanel> {
  final ScrollController _scrollController = ScrollController();
  final ParsedSegmentsCache _segmentsCache = ParsedSegmentsCache();
  String? _lastScrollKey;
  bool _isTtsScrolling = false;

  TtsGenerationController? _generationController;
  TtsStoredPlayerController? _playerController;
  TtsAudioDatabase? _playbackDb;
  String? _lastCheckedFileKey;

  @override
  void dispose() {
    _generationController?.cancel();
    _generationController = null;
    _playerController?.stop();
    _playerController = null;
    _playbackDb?.close();
    _playbackDb = null;
    _scrollController.dispose();
    super.dispose();
  }

  String? _currentNovelFolderPath() {
    return ref.read(currentDirectoryProvider);
  }

  String? _currentFileName() {
    return ref.read(selectedFileProvider)?.name;
  }

  Future<void> _checkAudioState() async {
    final folderPath = _currentNovelFolderPath();
    final fileName = _currentFileName();
    final selectedPath = ref.read(selectedFileProvider)?.path;
    if (folderPath == null || fileName == null || selectedPath == null) {
      ref.read(ttsAudioStateProvider.notifier).set(TtsAudioState.none);
      return;
    }

    if (_lastCheckedFileKey == selectedPath) return;
    _lastCheckedFileKey = selectedPath;

    final db = TtsAudioDatabase(folderPath);
    final repo = TtsAudioRepository(db);
    try {
      final episode = await repo.findEpisodeByFileName(fileName);
      if (episode != null && episode['status'] == 'completed') {
        ref.read(ttsAudioStateProvider.notifier).set(TtsAudioState.ready);
      } else {
        ref.read(ttsAudioStateProvider.notifier).set(TtsAudioState.none);
      }
    } finally {
      await db.close();
    }
  }

  Future<void> _startGeneration(String content) async {
    final folderPath = _currentNovelFolderPath();
    final fileName = _currentFileName();
    final modelDir = ref.read(ttsModelDirProvider);
    final refWavPath = ref.read(ttsRefWavPathProvider);

    if (folderPath == null || fileName == null || modelDir.isEmpty) return;

    ref.read(ttsAudioStateProvider.notifier).set(TtsAudioState.generating);
    ref.read(ttsGenerationProgressProvider.notifier)
        .set(const TtsGenerationProgress(current: 0, total: 0));

    final db = TtsAudioDatabase(folderPath);
    final repo = TtsAudioRepository(db);
    final isolate = TtsIsolate();

    final controller = TtsGenerationController(
      ttsIsolate: isolate,
      repository: repo,
    );
    _generationController = controller;

    controller.onSegmentStart = (textOffset, textLength) {
      if (!mounted) return;
      ref.read(ttsHighlightRangeProvider.notifier)
          .set(TextRange(start: textOffset, end: textOffset + textLength));
    };

    controller.onProgress = (current, total) {
      if (!mounted) return;
      ref.read(ttsGenerationProgressProvider.notifier)
          .set(TtsGenerationProgress(current: current, total: total));
    };

    controller.onError = (error) {
      if (!mounted) return;
      ref.read(ttsAudioStateProvider.notifier).set(TtsAudioState.none);
    };

    await controller.start(
      text: content,
      fileName: fileName,
      modelDir: modelDir,
      sampleRate: 24000,
      refWavPath: refWavPath.isNotEmpty ? refWavPath : null,
    );

    _generationController = null;
    await db.close();

    if (!mounted) return;

    ref.read(ttsHighlightRangeProvider.notifier).set(null);

    final audioState = ref.read(ttsAudioStateProvider);
    if (audioState == TtsAudioState.generating) {
      ref.read(ttsAudioStateProvider.notifier).set(TtsAudioState.ready);
    }
  }

  Future<void> _cancelGeneration() async {
    await _generationController?.cancel();
    _generationController = null;

    if (!mounted) return;
    ref.read(ttsHighlightRangeProvider.notifier).set(null);
    ref.read(ttsAudioStateProvider.notifier).set(TtsAudioState.none);
    _lastCheckedFileKey = null;
  }

  Future<void> _startPlayback(String content) async {
    final folderPath = _currentNovelFolderPath();
    final fileName = _currentFileName();
    if (folderPath == null || fileName == null) return;

    final container = ProviderScope.containerOf(context);
    final db = TtsAudioDatabase(folderPath);
    final repo = TtsAudioRepository(db);
    final episode = await repo.findEpisodeByFileName(fileName);
    if (episode == null) {
      await db.close();
      return;
    }

    _playbackDb = db;
    final tempDir = await getTemporaryDirectory();

    final controller = TtsStoredPlayerController(
      ref: container,
      audioPlayer: JustAudioPlayer(),
      repository: repo,
      tempDirPath: tempDir.path,
    );
    _playerController = controller;

    final selectedText = ref.read(selectedTextProvider);
    int? startOffset;
    if (selectedText != null && selectedText.isNotEmpty) {
      final index = content.indexOf(selectedText);
      if (index >= 0) startOffset = index;
    }

    await controller.start(
      episodeId: episode['id'] as int,
      startOffset: startOffset,
    );
  }

  Future<void> _pausePlayback() async {
    await _playerController?.pause();
  }

  Future<void> _resumePlayback() async {
    await _playerController?.resume();
  }

  Future<void> _stopPlayback() async {
    await _playerController?.stop();
    _playerController = null;
    await _playbackDb?.close();
    _playbackDb = null;
  }

  Future<void> _deleteAudio() async {
    final folderPath = _currentNovelFolderPath();
    final fileName = _currentFileName();
    if (folderPath == null || fileName == null) return;

    final db = TtsAudioDatabase(folderPath);
    final repo = TtsAudioRepository(db);
    final episode = await repo.findEpisodeByFileName(fileName);
    if (episode != null) {
      await repo.deleteEpisode(episode['id'] as int);
    }
    await db.close();

    if (!mounted) return;
    ref.read(ttsAudioStateProvider.notifier).set(TtsAudioState.none);
    _lastCheckedFileKey = null;
  }

  Widget _buildTtsControls(
      TtsAudioState audioState, TtsPlaybackState playbackState, String content) {
    switch (audioState) {
      case TtsAudioState.none:
        return FloatingActionButton.small(
          onPressed: () => _startGeneration(content),
          tooltip: '読み上げ音声生成',
          child: const Icon(Icons.record_voice_over),
        );
      case TtsAudioState.generating:
        final progress = ref.watch(ttsGenerationProgressProvider);
        final fraction =
            progress.total > 0 ? progress.current / progress.total : 0.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  LinearProgressIndicator(value: fraction),
                  const SizedBox(height: 2),
                  Text(
                    '${progress.current}/${progress.total}文',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: _cancelGeneration,
              tooltip: 'キャンセル',
              child: const Icon(Icons.close),
            ),
          ],
        );
      case TtsAudioState.ready:
        if (playbackState == TtsPlaybackState.playing) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                onPressed: _pausePlayback,
                tooltip: '一時停止',
                child: const Icon(Icons.pause),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _stopPlayback,
                tooltip: '停止',
                child: const Icon(Icons.stop),
              ),
            ],
          );
        } else if (playbackState == TtsPlaybackState.paused) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                onPressed: _resumePlayback,
                tooltip: '再開',
                child: const Icon(Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _stopPlayback,
                tooltip: '停止',
                child: const Icon(Icons.stop),
              ),
            ],
          );
        } else {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                onPressed: () => _startPlayback(content),
                tooltip: '再生',
                child: const Icon(Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _deleteAudio,
                tooltip: '音声データ削除',
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

      final fontSize = textStyle?.fontSize ?? 14.0;
      final lineHeight = (textStyle?.height ?? 1.5) * fontSize;
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

  void _scrollToLine(SelectedSearchMatch match, TextStyle? textStyle) {
    if (!mounted || !_scrollController.hasClients) return;

    final fontSize = textStyle?.fontSize ?? 14.0;
    final lineHeight = (textStyle?.height ?? 1.5) * fontSize;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final clampedOffset = ((match.lineNumber - 1) * lineHeight).clamp(0.0, maxOffset);

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

    return contentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('エラー: $error')),
      data: (content) {
        if (content == null) {
          return const Center(
            child: Text('ファイルを選択してください'),
          );
        }

        final ttsModelDir = ref.watch(ttsModelDirProvider);
        final audioState = ref.watch(ttsAudioStateProvider);
        final playbackState = ref.watch(ttsPlaybackStateProvider);
        final ttsHighlightRange = ref.watch(ttsHighlightRangeProvider);

        // Check audio state when file changes (deferred to avoid modifying providers during build)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkAudioState();
        });

        final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: fontSize,
              fontFamily: fontFamily.effectiveFontFamilyName,
            );
        final segments = _segmentsCache.getSegments(content);

        if (displayMode == TextDisplayMode.vertical) {
          final columnSpacing = ref.watch(columnSpacingProvider);
          return _withTtsControls(
            VerticalTextViewer(
              segments: segments,
              baseStyle: textStyle,
              query: activeMatch?.query,
              targetLineNumber: activeMatch?.lineNumber,
              ttsHighlightStart: ttsHighlightRange?.start,
              ttsHighlightEnd: ttsHighlightRange?.end,
              columnSpacing: columnSpacing,
              onSelectionChanged: (text) {
                ref.read(selectedTextProvider.notifier).setText(text);
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
        );

        if (activeMatch != null) {
          final scrollKey =
              '${activeMatch.filePath}:${activeMatch.lineNumber}:${activeMatch.query}';
          if (scrollKey != _lastScrollKey) {
            _lastScrollKey = scrollKey;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToLine(activeMatch, textStyle);
            });
          }
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
                _stopPlayback();
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
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
