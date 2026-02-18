import 'dart:math' show min, max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/data/search_models.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/ruby_text_parser.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';

class TextViewerPanel extends ConsumerStatefulWidget {
  const TextViewerPanel({super.key});

  @override
  ConsumerState<TextViewerPanel> createState() => _TextViewerPanelState();
}

class _TextViewerPanelState extends ConsumerState<TextViewerPanel> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrollKey;
  bool _isTtsScrolling = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _stopTts() {
    ref.read(ttsPlaybackStateProvider.notifier).set(TtsPlaybackState.stopped);
    ref.read(ttsHighlightRangeProvider.notifier).set(null);
  }

  Widget _buildTtsButton(TtsPlaybackState ttsState) {
    switch (ttsState) {
      case TtsPlaybackState.loading:
        return const SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      case TtsPlaybackState.playing:
        return FloatingActionButton.small(
          onPressed: () {
            // TODO: stop TTS playback
          },
          child: const Icon(Icons.stop),
        );
      case TtsPlaybackState.stopped:
        return FloatingActionButton.small(
          onPressed: () {
            // TODO: start TTS playback
          },
          child: const Icon(Icons.play_arrow),
        );
    }
  }

  Widget _withTtsButton(Widget child, String ttsModelDir, TtsPlaybackState ttsState) {
    if (ttsModelDir.isEmpty) return child;
    return Stack(
      children: [
        child,
        Positioned(
          right: 8,
          bottom: 8,
          child: _buildTtsButton(ttsState),
        ),
      ],
    );
  }

  void _scrollToTtsHighlight(
      String content, TextRange range, TextStyle? textStyle) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      // Count newlines before the TTS highlight start to estimate the line number
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
        final ttsState = ref.watch(ttsPlaybackStateProvider);
        final ttsHighlightRange = ref.watch(ttsHighlightRangeProvider);

        final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: fontSize,
              fontFamily: fontFamily.effectiveFontFamilyName,
            );
        final segments = parseRubyText(content);

        if (displayMode == TextDisplayMode.vertical) {
          final columnSpacing = ref.watch(columnSpacingProvider);
          return _withTtsButton(
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
              onUserPageChange: () {
                if (ttsState == TtsPlaybackState.playing) {
                  _stopTts();
                }
              },
            ),
            ttsModelDir,
            ttsState,
          );
        }

        // Horizontal mode (existing behavior)
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

        return _withTtsButton(
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (!_isTtsScrolling &&
                  notification is ScrollStartNotification &&
                  notification.dragDetails != null &&
                  ttsState == TtsPlaybackState.playing) {
                _stopTts();
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
          ttsState,
        );
      },
    );
  }
}
