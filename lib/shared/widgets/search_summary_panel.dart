import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_panel.dart';
import 'package:novel_viewer/features/text_search/presentation/search_results_panel.dart';

class SearchSummaryPanel extends ConsumerWidget {
  const SearchSummaryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      children: [
        Expanded(
          key: Key('llm_summary_section'),
          child: LlmSummaryPanel(),
        ),
        Divider(height: 1),
        Expanded(
          flex: 2,
          key: Key('search_results_section'),
          child: SearchResultsPanel(),
        ),
      ],
    );
  }
}
