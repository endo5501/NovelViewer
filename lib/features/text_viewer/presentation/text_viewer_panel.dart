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

class TextViewerPanel extends ConsumerStatefulWidget {
  const TextViewerPanel({super.key});

  @override
  ConsumerState<TextViewerPanel> createState() => _TextViewerPanelState();
}

class _TextViewerPanelState extends ConsumerState<TextViewerPanel> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrollKey;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLine(SelectedSearchMatch match, TextStyle? textStyle) {
    if (!mounted || !_scrollController.hasClients) return;

    final fontSize = textStyle?.fontSize ?? 14.0;
    final lineHeight = (textStyle?.height ?? 1.5) * fontSize;
    final targetOffset = (match.lineNumber - 1) * lineHeight;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);

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

        final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: fontSize,
              fontFamily: fontFamily.effectiveFontFamilyName,
            );
        final segments = parseRubyText(content);

        if (displayMode == TextDisplayMode.vertical) {
          final columnSpacing = ref.watch(columnSpacingProvider);
          return VerticalTextViewer(
            segments: segments,
            baseStyle: textStyle,
            query: activeMatch?.query,
            targetLineNumber: activeMatch?.lineNumber,
            columnSpacing: columnSpacing,
            onSelectionChanged: (text) {
              ref.read(selectedTextProvider.notifier).setText(text);
            },
          );
        }

        // Horizontal mode (existing behavior)
        final textSpan = buildRubyTextSpans(
          segments,
          textStyle,
          activeMatch?.query,
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

        return SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16.0),
          child: SelectableText.rich(
            textSpan,
            onSelectionChanged: (selection, cause) {
              final start = selection.start < selection.end
                  ? selection.start
                  : selection.end;
              final end = selection.start > selection.end
                  ? selection.start
                  : selection.end;
              final selectedText = extractSelectedText(start, end, segments);
              ref.read(selectedTextProvider.notifier).setText(
                    selectedText.isEmpty ? null : selectedText,
                  );
            },
          ),
        );
      },
    );
  }
}
