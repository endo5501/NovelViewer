import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:path/path.dart' as p;

class LlmSummaryPanel extends ConsumerWidget {
  const LlmSummaryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'ネタバレなし'),
              Tab(text: 'ネタバレあり'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SummaryTabContent(
                  summaryType: SummaryType.noSpoiler,
                  summaryProvider: llmNoSpoilerSummaryProvider,
                ),
                _SummaryTabContent(
                  summaryType: SummaryType.spoiler,
                  summaryProvider: llmSpoilerSummaryProvider,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTabContent extends ConsumerStatefulWidget {
  final SummaryType summaryType;
  final NotifierProvider<LlmSummaryNotifier, LlmSummaryState> summaryProvider;

  const _SummaryTabContent({
    required this.summaryType,
    required this.summaryProvider,
  });

  @override
  ConsumerState<_SummaryTabContent> createState() =>
      _SummaryTabContentState();
}

class _SummaryTabContentState extends ConsumerState<_SummaryTabContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCacheForCurrentWord();
    });
  }

  void _loadCacheForCurrentWord() {
    final selectedText = ref.read(selectedTextProvider);
    final directory = ref.read(currentDirectoryProvider);
    if (selectedText != null &&
        selectedText.isNotEmpty &&
        directory != null) {
      final folderName = p.basename(directory);
      ref.read(widget.summaryProvider.notifier).loadCache(
            folderName: folderName,
            word: selectedText,
            summaryType: widget.summaryType,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedText = ref.watch(selectedTextProvider);
    final llmConfig = ref.watch(llmConfigProvider);
    final summaryState = ref.watch(widget.summaryProvider);

    ref.listen(selectedTextProvider, (previous, next) {
      if (next != previous) {
        _loadCacheForCurrentWord();
      }
    });

    if (selectedText == null || selectedText.isEmpty) {
      return const Center(child: Text('単語を選択してください'));
    }

    if (!llmConfig.isConfigured) {
      return const Center(child: Text('設定画面でLLMを設定してください'));
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: _buildContent(summaryState),
            ),
          ),
          const SizedBox(height: 8),
          _buildAnalyzeButton(summaryState),
        ],
      ),
    );
  }

  Widget _buildContent(LlmSummaryState summaryState) {
    if (summaryState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (summaryState.error != null) {
      return Text(
        'エラー: ${summaryState.error}',
        style: const TextStyle(color: Colors.red),
      );
    }

    if (summaryState.currentSummary != null) {
      final selectedFile = ref.watch(selectedFileProvider);
      final widgets = <Widget>[
        SelectableText(summaryState.currentSummary!),
      ];

      if (widget.summaryType == SummaryType.noSpoiler &&
          summaryState.cachedSummary?.sourceFile != null &&
          selectedFile != null &&
          summaryState.cachedSummary!.sourceFile != selectedFile.name) {
        widgets.insert(
          0,
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '基準位置が異なります。再解析をお勧めします。',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAnalyzeButton(LlmSummaryState summaryState) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: summaryState.isLoading
            ? null
            : () => ref
                .read(widget.summaryProvider.notifier)
                .analyze(summaryType: widget.summaryType),
        child: const Text('解析開始'),
      ),
    );
  }
}
