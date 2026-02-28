import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    testWidgets('clicking match line updates selectedSearchMatchProvider',
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
            searchQueryProvider.overrideWith(() {
              final notifier = SearchQueryNotifier();
              return notifier;
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      // Set search query first
      final element = tester.element(find.byType(SearchResultsPanel));
      final container = ProviderScope.containerOf(element);
      container.read(searchQueryProvider.notifier).setQuery('太郎');

      await tester.tap(find.textContaining('L3: 太郎が走った'));
      await tester.pump();

      final match = container.read(selectedSearchMatchProvider);
      expect(match, isNotNull);
      expect(match!.filePath, '/path/to/001.txt');
      expect(match.lineNumber, 3);
      expect(match.query, '太郎');
    });

    testWidgets('clicking match line also updates selectedFileProvider',
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
            searchQueryProvider.overrideWith(() {
              final notifier = SearchQueryNotifier();
              return notifier;
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SearchResultsPanel));
      final container = ProviderScope.containerOf(element);
      container.read(searchQueryProvider.notifier).setQuery('太郎');

      await tester.tap(find.textContaining('L3: 太郎が走った'));
      await tester.pump();

      final selectedFile = container.read(selectedFileProvider);
      expect(selectedFile, isNotNull);
      expect(selectedFile!.name, '001.txt');
      expect(selectedFile.path, '/path/to/001.txt');
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

    testWidgets('shows search box when searchBoxVisibleProvider is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SearchResultsPanel));
      final container = ProviderScope.containerOf(element);
      container.read(searchBoxVisibleProvider.notifier).show();
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('hides search box when searchBoxVisibleProvider is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('search box onSubmitted sets searchQueryProvider',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SearchResultsPanel));
      final container = ProviderScope.containerOf(element);
      container.read(searchBoxVisibleProvider.notifier).show();
      await tester.pump();

      await tester.enterText(find.byType(TextField), '太郎');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(container.read(searchQueryProvider), '太郎');
    });

    testWidgets('search box onSubmitted with empty string clears query',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SearchResultsPanel));
      final container = ProviderScope.containerOf(element);

      // Set a query first
      container.read(searchQueryProvider.notifier).setQuery('太郎');
      container.read(searchBoxVisibleProvider.notifier).show();
      await tester.pump();

      await tester.enterText(find.byType(TextField), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(container.read(searchQueryProvider), isNull);
    });

    testWidgets('search box onSubmitted with whitespace-only string clears query',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SearchResultsPanel));
      final container = ProviderScope.containerOf(element);
      container.read(searchBoxVisibleProvider.notifier).show();
      await tester.pump();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(container.read(searchQueryProvider), isNull);
    });

    testWidgets('Escape key hides search box and clears query',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SearchResultsPanel));
      final container = ProviderScope.containerOf(element);

      // Set a query and show search box
      container.read(searchQueryProvider.notifier).setQuery('太郎');
      container.read(searchBoxVisibleProvider.notifier).show();
      await tester.pump();

      // Focus the text field and press Escape
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(container.read(searchBoxVisibleProvider), isFalse);
      expect(container.read(searchQueryProvider), isNull);
    });

    testWidgets('external hide clears TextField text for next show',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SearchResultsPanel));
      final container = ProviderScope.containerOf(element);

      // Show search box and enter text
      container.read(searchBoxVisibleProvider.notifier).show();
      await tester.pump();
      await tester.enterText(find.byType(TextField), '太郎');
      await tester.pump();

      // Externally hide (simulates global Escape from HomeScreen)
      container.read(searchBoxVisibleProvider.notifier).hide();
      await tester.pump();

      // Show again
      container.read(searchBoxVisibleProvider.notifier).show();
      await tester.pump();

      // TextField should be empty
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
    });

    testWidgets(
        'clicking file name clears selectedSearchMatchProvider',
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
            selectedSearchMatchProvider.overrideWith(() {
              return SelectedSearchMatchNotifier();
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: SearchResultsPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SearchResultsPanel));
      final container = ProviderScope.containerOf(element);

      // Set a search match first
      container.read(selectedSearchMatchProvider.notifier).select(
            filePath: '/path/to/001.txt',
            lineNumber: 3,
            query: '太郎',
          );

      // Click file name header
      await tester.tap(find.text('001.txt'));
      await tester.pump();

      expect(container.read(selectedSearchMatchProvider), isNull);
    });
  });
}
