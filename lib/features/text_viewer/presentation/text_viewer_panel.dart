import 'dart:math' show min, max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/parsed_segments_cache_provider.dart';
import 'package:novel_viewer/features/text_viewer/data/ruby_text_parser.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/tts_controls_bar.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_dictionary_repository.dart';
import 'package:novel_viewer/features/tts/presentation/dictionary_context_menu.dart';
import 'package:novel_viewer/features/tts/presentation/tts_dictionary_dialog.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/utils/content_hash.dart';

class TextViewerPanel extends ConsumerStatefulWidget {
  const TextViewerPanel({super.key});

  @override
  ConsumerState<TextViewerPanel> createState() => _TextViewerPanelState();
}

class _TextViewerPanelState extends ConsumerState<TextViewerPanel> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrollKey;
  String? _lastViewedFilePath;
  bool _isTtsScrolling = false;
  int _lastReportedViewLine = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateCurrentViewLine);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    final clampedOffset =
        _lineNumberToOffset(lineNumber, textStyle).clamp(0.0, maxOffset);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _withTtsControlsOverlay(Widget child, String content) {
    return Stack(
      children: [
        child,
        Positioned(
          right: 8,
          bottom: 8,
          child: TtsControlsBar(content: content),
        ),
      ],
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
      error: (error, _) => Center(
          child: Text(AppLocalizations.of(context)!
              .common_errorPrefix(error.toString()))),
      data: (content) {
        if (content == null) {
          return Center(
            child: Text(
                AppLocalizations.of(context)!.textViewer_selectFilePrompt),
          );
        }

        final playbackState = ref.watch(ttsPlaybackStateProvider);
        final ttsHighlightRange = ref.watch(ttsHighlightRangeProvider);

        final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: fontSize,
              fontFamily: fontFamily.effectiveFontFamilyName,
            );
        final segments = ref
            .watch(parsedSegmentsCacheProvider)
            .getOrParse(content, computeContentHash(content), parseRubyText);

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
          return _withTtsControlsOverlay(
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

        return _withTtsControlsOverlay(
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (!_isTtsScrolling &&
                  notification is ScrollStartNotification &&
                  notification.dragDetails != null &&
                  playbackState == TtsPlaybackState.playing) {
                ref.read(ttsStopRequestProvider.notifier).request();
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
          content,
        );
      },
    );
  }
}

enum _ContextMenuAction { copy, addToDictionary }
