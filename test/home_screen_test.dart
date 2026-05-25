import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/app/selected_file_progress_title_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/presentation/search_results_panel.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/shared/providers/layout_providers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  group('HomeScreen 3-column layout', () {
    testWidgets('right column is hidden by default on launch',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );

      expect(find.byKey(const Key('left_column')), findsOneWidget);
      expect(find.byKey(const Key('center_column')), findsOneWidget);
      expect(find.byKey(const Key('right_column')), findsNothing);
      expect(find.byType(VerticalDivider), findsNWidgets(1));
    });

    testWidgets('displays three columns separated by vertical dividers when right column shown',
        (WidgetTester tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );

      container = ProviderScope.containerOf(
        tester.element(find.byType(NovelViewerApp)),
      );
      container.read(rightColumnVisibleProvider.notifier).toggle();
      await tester.pump();

      expect(find.byKey(const Key('left_column')), findsOneWidget);
      expect(find.byKey(const Key('center_column')), findsOneWidget);
      expect(find.byKey(const Key('right_column')), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNWidgets(2));
    });

    testWidgets('left column has fixed width', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );

      final leftColumn = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byKey(const Key('left_column')),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(leftColumn.width, isNotNull);
    });

    testWidgets('right column has fixed width when shown',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(NovelViewerApp)),
      );
      container.read(rightColumnVisibleProvider.notifier).toggle();
      await tester.pump();

      final rightColumn = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byKey(const Key('right_column')),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(rightColumn.width, isNotNull);
    });

    testWidgets('right column is a SearchResultsPanel (no wrapper) when shown',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(NovelViewerApp)),
      );
      container.read(rightColumnVisibleProvider.notifier).toggle();
      await tester.pump();

      final rightColumnWidget =
          tester.widget(find.byKey(const Key('right_column')));
      expect(rightColumnWidget, isA<SearchResultsPanel>(),
          reason:
              'After llm-summary-hover-popup the right column is search-only '
              '— it should be a SearchResultsPanel directly, not a wrapper');
    });
  });

  group('HomeScreen AppBar title', () {
    testWidgets('shows NovelViewer when no novel is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
            selectedNovelTitleProvider
                .overrideWith((ref) async => null),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final titleWidget = appBar.title as Text;
      expect(titleWidget.data, 'NovelViewer');
    });

    testWidgets('shows novel title when a novel is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
            selectedNovelTitleProvider
                .overrideWith((ref) async => '異世界転生物語'),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final titleWidget = appBar.title as Text;
      expect(titleWidget.data, '異世界転生物語');
    });

    testWidgets('shows "name (N/M)" suffix when a file is selected',
        (WidgetTester tester) async {
      const file = FileEntry(
        name: '049-戦闘.txt',
        path: '/library/n1234/049-戦闘.txt',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
            selectedFileProgressTitleProvider
                .overrideWithValue('異世界転生 — 049-戦闘.txt (49/200)'),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();
      // Touch the FileEntry constant so it is not flagged unused.
      expect(file.name, '049-戦闘.txt');

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final titleWidget = appBar.title as Text;
      expect(titleWidget.data, '異世界転生 — 049-戦闘.txt (49/200)');
    });

    testWidgets('title uses ellipsis overflow with maxLines=1',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
            selectedFileProgressTitleProvider.overrideWithValue(
              '非常に長い小説タイトルがここにあって — '
              '049-非常に長いエピソードタイトル.txt (49/200)',
            ),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final titleWidget = appBar.title as Text;
      expect(titleWidget.maxLines, 1);
      expect(titleWidget.overflow, TextOverflow.ellipsis);
    });
  });

  group('HomeScreen right column toggle', () {
    const toggleButtonKey = Key('toggle_right_column_button');

    testWidgets('toggle button is displayed in AppBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );

      expect(find.byKey(toggleButtonKey), findsOneWidget);
    });

    testWidgets('clicking toggle shows right column and divider',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );

      // Initially right column is hidden (default false)
      expect(find.byKey(const Key('right_column')), findsNothing);
      expect(find.byType(VerticalDivider), findsNWidgets(1));

      // Click toggle button
      await tester.tap(find.byKey(toggleButtonKey));
      await tester.pump();

      // Right column and its divider should now be visible
      expect(find.byKey(const Key('right_column')), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNWidgets(2));
    });

    testWidgets('icon is view_sidebar by default (right column hidden)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );

      expect(find.byIcon(Icons.view_sidebar), findsOneWidget);
      expect(find.byIcon(Icons.vertical_split), findsNothing);
    });

    testWidgets('icon changes to vertical_split when right column is shown',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );

      // Click toggle to show
      await tester.tap(find.byKey(toggleButtonKey));
      await tester.pump();

      expect(find.byIcon(Icons.vertical_split), findsOneWidget);
      expect(find.byIcon(Icons.view_sidebar), findsNothing);
    });

    testWidgets('clicking toggle twice returns to hidden state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );

      // Show
      await tester.tap(find.byKey(toggleButtonKey));
      await tester.pump();
      expect(find.byKey(const Key('right_column')), findsOneWidget);

      // Hide again
      await tester.tap(find.byKey(toggleButtonKey));
      await tester.pump();

      expect(find.byKey(const Key('right_column')), findsNothing);
      expect(find.byType(VerticalDivider), findsNWidgets(1));
      expect(find.byIcon(Icons.view_sidebar), findsOneWidget);
    });
  });

  group('HomeScreen keyboard shortcuts', () {
    testWidgets('Ctrl+F sets searchQueryProvider from selectedTextProvider',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: Builder(
            builder: (context) {
              return ProviderScope(
                overrides: [
                  sharedPreferencesProvider.overrideWithValue(prefs),
                  libraryPathProvider.overrideWithValue('/library'),
                ],
                child: const NovelViewerApp(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(NovelViewerApp).last);
      container = ProviderScope.containerOf(element);

      container.read(selectedTextProvider.notifier).setText('太郎');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      expect(container.read(searchQueryProvider), '太郎');
    });

    testWidgets('Ctrl+F with selected text clears stale selectedSearchMatch',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(NovelViewerApp));
      container = ProviderScope.containerOf(element);

      // Simulate stale match from a previous search
      container.read(searchQueryProvider.notifier).setQuery('太郎');
      container.read(selectedSearchMatchProvider.notifier).select(
            filePath: '/path/to/001.txt',
            lineNumber: 3,
            query: '太郎',
          );
      container.read(selectedTextProvider.notifier).setText('花子');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      expect(container.read(searchQueryProvider), '花子');
      expect(container.read(selectedSearchMatchProvider), isNull,
          reason: 'Ctrl+F with new selected text should clear stale '
              'selectedSearchMatch from a previous search');
    });

    testWidgets('Ctrl+F shows search box when no text is selected',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(NovelViewerApp));
      container = ProviderScope.containerOf(element);

      expect(container.read(searchBoxVisibleProvider), isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      expect(container.read(searchBoxVisibleProvider), isTrue);
      expect(container.read(searchQueryProvider), isNull);
    });

    testWidgets('Ctrl+F auto-shows right column when initially hidden',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(NovelViewerApp));
      container = ProviderScope.containerOf(element);

      // Right column starts hidden (default false)
      expect(container.read(rightColumnVisibleProvider), isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      expect(container.read(rightColumnVisibleProvider), isTrue);
      expect(container.read(searchBoxVisibleProvider), isTrue);
    });

    testWidgets('Escape clears search when search box is visible',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(NovelViewerApp));
      container = ProviderScope.containerOf(element);

      // Activate search box
      container.read(searchBoxVisibleProvider.notifier).show();
      container.read(searchQueryProvider.notifier).setQuery('太郎');
      await tester.pump();

      // Press Escape (focus is NOT on the search box)
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(container.read(searchBoxVisibleProvider), isFalse);
      expect(container.read(searchQueryProvider), isNull);
    });

    testWidgets('Escape clears search when query is active but search box is hidden',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(NovelViewerApp));
      container = ProviderScope.containerOf(element);

      // Set query without showing search box (simulates selection-based search)
      container.read(searchQueryProvider.notifier).setQuery('太郎');
      await tester.pump();

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(container.read(searchQueryProvider), isNull);
    });

    testWidgets('Escape clears selectedSearchMatchProvider as well',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(NovelViewerApp));
      container = ProviderScope.containerOf(element);

      // Simulate a search match selection (clicking a result row)
      container.read(searchQueryProvider.notifier).setQuery('太郎');
      container.read(selectedSearchMatchProvider.notifier).select(
            filePath: '/path/to/001.txt',
            lineNumber: 3,
            query: '太郎',
          );
      await tester.pump();

      expect(container.read(selectedSearchMatchProvider), isNotNull);

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(container.read(selectedSearchMatchProvider), isNull,
          reason: 'Escape should clear selectedSearchMatch '
              'so the orange highlight disappears');
    });

    testWidgets('Escape does nothing when no search is active',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(NovelViewerApp));
      container = ProviderScope.containerOf(element);

      // No search active
      expect(container.read(searchBoxVisibleProvider), isFalse);
      expect(container.read(searchQueryProvider), isNull);

      // Press Escape - should not cause any error
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(container.read(searchBoxVisibleProvider), isFalse);
      expect(container.read(searchQueryProvider), isNull);
    });
  });
}
