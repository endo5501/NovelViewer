import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_search/data/search_models.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';

class SearchResultsPanel extends ConsumerStatefulWidget {
  const SearchResultsPanel({super.key});

  @override
  ConsumerState<SearchResultsPanel> createState() =>
      _SearchResultsPanelState();
}

class _SearchResultsPanelState extends ConsumerState<SearchResultsPanel> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        _onEscape();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    ref.listenManual(searchBoxVisibleProvider, (previous, next) {
      if (next && !_focusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSubmitted(String value) {
    final trimmed = value.trim();
    ref.read(searchQueryProvider.notifier).setQuery(trimmed.isEmpty ? null : trimmed);
  }

  void _onEscape() {
    ref.read(searchBoxVisibleProvider.notifier).hide();
    ref.read(searchQueryProvider.notifier).setQuery(null);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isSearchBoxVisible = ref.watch(searchBoxVisibleProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Column(
      children: [
        if (isSearchBoxVisible)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                hintText: '検索...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: _onSubmitted,
            ),
          ),
        Expanded(
          child: resultsAsync.when(
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
          ),
        ),
      ],
    );
  }
}

class _SearchResultFileGroup extends ConsumerWidget {
  final SearchResult result;

  const _SearchResultFileGroup({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileEntry = FileEntry(
      name: result.fileName,
      path: result.filePath,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            ref.read(selectedFileProvider.notifier).selectFile(fileEntry);
            ref.read(selectedSearchMatchProvider.notifier).clear();
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
        ...result.matches.map((match) => InkWell(
              onTap: () {
                ref.read(selectedFileProvider.notifier).selectFile(fileEntry);
                final query = ref.read(searchQueryProvider);
                if (query != null) {
                  ref.read(selectedSearchMatchProvider.notifier).select(
                        filePath: result.filePath,
                        lineNumber: match.lineNumber,
                        query: query,
                      );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 2.0),
                child: Text(
                  'L${match.lineNumber}: ${match.contextText}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )),
        const Divider(height: 8),
      ],
    );
  }
}
