import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_search/data/search_models.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:novel_viewer/shared/providers/layout_providers.dart';

/// Closes the search session in one place: hides the search box, clears the
/// query and selected match, and closes the (now search-only) right column so
/// no empty column is left behind.
///
/// Shared by the Ctrl+F toggle (HomeScreen) and the search field's Escape
/// handler (SearchResultsPanel), so both dismiss paths behave identically.
void closeSearchSession(WidgetRef ref) {
  ref.read(searchBoxVisibleProvider.notifier).hide();
  ref.read(selectedSearchMatchProvider.notifier).clear();
  ref.read(searchQueryProvider.notifier).setQuery(null);
  if (ref.read(rightColumnVisibleProvider)) {
    ref.read(rightColumnVisibleProvider.notifier).toggle();
  }
}

class SearchBoxVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;

  void hide() => state = false;
}

final searchBoxVisibleProvider =
    NotifierProvider<SearchBoxVisibleNotifier, bool>(
  SearchBoxVisibleNotifier.new,
);

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
  final results = await service.search(directory, query);
  return _sortByNumericPrefix(results);
});

class SelectedSearchMatchNotifier extends Notifier<SelectedSearchMatch?> {
  @override
  SelectedSearchMatch? build() => null;

  void select({
    required String filePath,
    required int lineNumber,
    required String query,
  }) {
    state = SelectedSearchMatch(
      filePath: filePath,
      lineNumber: lineNumber,
      query: query,
    );
  }

  void clear() => state = null;
}

final selectedSearchMatchProvider =
    NotifierProvider<SelectedSearchMatchNotifier, SelectedSearchMatch?>(
        SelectedSearchMatchNotifier.new);

List<SearchResult> _sortByNumericPrefix(List<SearchResult> results) {
  final numericPrefixRegExp = RegExp(r'^(\d+)');

  int? extractNumericPrefix(String fileName) {
    final match = numericPrefixRegExp.firstMatch(fileName);
    return match != null ? int.parse(match.group(1)!) : null;
  }

  final numbered = <(SearchResult, int)>[];
  final nonNumbered = <SearchResult>[];

  for (final result in results) {
    final number = extractNumericPrefix(result.fileName);
    if (number != null) {
      numbered.add((result, number));
    } else {
      nonNumbered.add(result);
    }
  }

  numbered.sort((a, b) {
    final byNum = a.$2.compareTo(b.$2);
    if (byNum != 0) return byNum;
    return a.$1.fileName.compareTo(b.$1.fileName);
  });
  nonNumbered.sort((a, b) => a.fileName.compareTo(b.fileName));

  return [...numbered.map((e) => e.$1), ...nonNumbered];
}
