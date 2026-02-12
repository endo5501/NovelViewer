import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_search/data/search_models.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/ruby_text_parser.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';
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

    final activeMatch =
        (searchMatch != null && selectedFile?.path == searchMatch.filePath)
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

        final textStyle = Theme.of(context).textTheme.bodyMedium;
        final segments = parseRubyText(content);
        final textSpan = buildRubyTextSpans(
          segments,
          textStyle,
          activeMatch?.query,
        );

        final scrollKey = activeMatch == null
            ? null
            : '${activeMatch.filePath}:${activeMatch.lineNumber}:${activeMatch.query}';

        if (scrollKey != null && scrollKey != _lastScrollKey) {
          _lastScrollKey = scrollKey;
          final matchToScroll = activeMatch!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToLine(matchToScroll, textStyle);
          });
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
              final end = selection.start < selection.end
                  ? selection.end
                  : selection.start;
              final selectedText =
                  extractSelectedText(start, end, segments);
              ref
                  .read(selectedTextProvider.notifier)
                  .setText(selectedText.isEmpty ? null : selectedText);
            },
          ),
        );
      },
    );
  }
}
