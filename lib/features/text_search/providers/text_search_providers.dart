import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_search/data/search_models.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';

class SearchQueryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setQuery(String? query) => state = query;
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String?>(SearchQueryNotifier.new);

final textSearchServiceProvider = Provider<TextSearchService>((ref) {
  return TextSearchService();
});

final searchResultsProvider =
    FutureProvider<List<SearchResult>?>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final directory = ref.watch(currentDirectoryProvider);

  if (query == null || directory == null) return null;

  final service = ref.watch(textSearchServiceProvider);
  return service.search(directory, query);
});
