import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/text_search/data/search_models.dart';
import 'package:novel_viewer/features/text_search/presentation/search_results_panel.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

void main() {
  group('SearchResultsPanel', () {
    testWidgets('shows placeholder when no search has been executed',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('検索語を入力してください'), findsOneWidget);
    });

    testWidgets('shows loading indicator during search',
        (WidgetTester tester) async {
      final completer = Completer<List<SearchResult>?>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchResultsProvider
                .overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('shows no results message when search returns empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchResultsProvider
                .overrideWith((ref) async => <SearchResult>[]),
          ],
          child: const MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('検索結果がありません'), findsOneWidget);
    });

    testWidgets('displays search results grouped by file',
        (WidgetTester tester) async {
      final results = [
        const SearchResult(
          fileName: '001.txt',
          filePath: '/path/to/001.txt',
          matches: [
            SearchMatch(lineNumber: 3, contextText: '太郎が走った'),
          ],
        ),
        const SearchResult(
          fileName: '002.txt',
          filePath: '/path/to/002.txt',
          matches: [
            SearchMatch(lineNumber: 5, contextText: '太郎が言った'),
            SearchMatch(lineNumber: 10, contextText: '太郎が笑った'),
          ],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchResultsProvider.overrideWith((ref) async => results),
          ],
          child: const MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('001.txt'), findsOneWidget);
      expect(find.text('002.txt'), findsOneWidget);
      expect(find.textContaining('太郎が走った'), findsOneWidget);
      expect(find.textContaining('太郎が言った'), findsOneWidget);
      expect(find.textContaining('太郎が笑った'), findsOneWidget);
    });

    testWidgets('displays line numbers with context',
        (WidgetTester tester) async {
      final results = [
        const SearchResult(
          fileName: '001.txt',
          filePath: '/path/to/001.txt',
          matches: [
            SearchMatch(lineNumber: 3, contextText: '太郎が走った'),
          ],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchResultsProvider.overrideWith((ref) async => results),
          ],
          child: const MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('L3'), findsOneWidget);
    });

    testWidgets('clicking file name updates selectedFileProvider',
        (WidgetTester tester) async {
      final results = [
        const SearchResult(
          fileName: '001.txt',
          filePath: '/path/to/001.txt',
          matches: [
            SearchMatch(lineNumber: 3, contextText: '太郎が走った'),
          ],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchResultsProvider.overrideWith((ref) async => results),
          ],
          child: const MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('001.txt'));
      await tester.pump();

      final element = tester.element(find.byType(SearchResultsPanel));
      final container = ProviderScope.containerOf(element);
      final selectedFile = container.read(selectedFileProvider);

      expect(selectedFile, isNotNull);
      expect(selectedFile!.name, '001.txt');
      expect(selectedFile.path, '/path/to/001.txt');
    });
  });
}
