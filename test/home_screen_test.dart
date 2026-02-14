import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  group('HomeScreen 3-column layout', () {
    testWidgets('displays three columns separated by vertical dividers',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const NovelViewerApp(),
        ),
      );

      expect(find.byKey(const Key('left_column')), findsOneWidget);
      expect(find.byKey(const Key('center_column')), findsOneWidget);
      expect(find.byKey(const Key('right_column')), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNWidgets(2));
    });

    testWidgets('left column has fixed width', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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

    testWidgets('right column has fixed width', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const NovelViewerApp(),
        ),
      );

      final rightColumn = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byKey(const Key('right_column')),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(rightColumn.width, isNotNull);
    });
  });

  group('HomeScreen AppBar title', () {
    testWidgets('shows NovelViewer when no novel is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
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
  });

  group('HomeScreen keyboard shortcuts', () {
    testWidgets('Ctrl+F sets searchQueryProvider from selectedTextProvider',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: Builder(
            builder: (context) {
              return ProviderScope(
                overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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

    testWidgets('Ctrl+F does nothing when no text is selected',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(NovelViewerApp));
      container = ProviderScope.containerOf(element);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      expect(container.read(searchQueryProvider), isNull);
    });
  });
}
