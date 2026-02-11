import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/text_search/presentation/search_results_panel.dart';

class SearchSummaryPanel extends ConsumerWidget {
  const SearchSummaryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          key: const Key('llm_summary_section'),
          child: Center(
            child: Text(
              'LLM要約',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        const Divider(height: 1),
        const Expanded(
          flex: 2,
          key: Key('search_results_section'),
          child: SearchResultsPanel(),
        ),
      ],
    );
  }
}
