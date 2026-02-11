import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_search/data/search_models.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';

class SearchResultsPanel extends ConsumerWidget {
  const SearchResultsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider);

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('エラー: $error')),
      data: (results) {
        if (results == null) {
          return const Center(child: Text('検索語を入力してください'));
        }

        if (results.isEmpty) {
          return const Center(child: Text('検索結果がありません'));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            return _SearchResultFileGroup(result: result);
          },
        );
      },
    );
  }
}

class _SearchResultFileGroup extends ConsumerWidget {
  final SearchResult result;

  const _SearchResultFileGroup({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            ref.read(selectedFileProvider.notifier).selectFile(
                  FileEntry(
                    name: result.fileName,
                    path: result.filePath,
                  ),
                );
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              result.fileName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        ),
        ...result.matches.map((match) => Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
              child: Text(
                'L${match.lineNumber}: ${match.contextText}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )),
        const Divider(height: 8),
      ],
    );
  }
}
