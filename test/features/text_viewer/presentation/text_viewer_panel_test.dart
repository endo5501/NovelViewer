import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  group('TextViewerPanel', () {
    testWidgets('shows placeholder when no file is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ファイルを選択してください'), findsOneWidget);
    });

    testWidgets('shows file content when file is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('テスト小説の内容です。'), findsOneWidget);
    });

    testWidgets('content is scrollable', (WidgetTester tester) async {
      final longText = List.generate(100, (i) => '行$i: テスト').join('\n');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            fileContentProvider.overrideWith((ref) async => longText),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('text is selectable', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('has onSelectionChanged callback wired up',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final selectableText =
          tester.widget<SelectableText>(find.byType(SelectableText));
      expect(selectableText.onSelectionChanged, isNotNull);
    });

    testWidgets(
        'uses SelectableText.rich with highlighted spans when search match is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            fileContentProvider.overrideWith(
                (ref) async => '太郎が走った。次郎が歩いた。太郎が言った。'),
            selectedSearchMatchProvider.overrideWith(() {
              return SelectedSearchMatchNotifier();
            }),
            selectedFileProvider.overrideWith(() {
              final notifier = SelectedFileNotifier();
              return notifier;
            }),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(name: 'file.txt', path: '/path/to/file.txt'),
          );
      container.read(selectedSearchMatchProvider.notifier).select(
            filePath: '/path/to/file.txt',
            lineNumber: 1,
            query: '太郎',
          );
      await tester.pumpAndSettle();

      final selectableText =
          tester.widget<SelectableText>(find.byType(SelectableText));
      expect(selectableText.textSpan, isNotNull);
    });

    testWidgets('no highlights when search match filePath does not match',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            fileContentProvider
                .overrideWith((ref) async => '太郎が走った。'),
            selectedSearchMatchProvider.overrideWith(() {
              return SelectedSearchMatchNotifier();
            }),
            selectedFileProvider.overrideWith(() {
              return SelectedFileNotifier();
            }),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(
                name: 'other.txt', path: '/path/to/other.txt'),
          );
      container.read(selectedSearchMatchProvider.notifier).select(
            filePath: '/path/to/different.txt',
            lineNumber: 1,
            query: '太郎',
          );
      await tester.pumpAndSettle();

      final selectableText =
          tester.widget<SelectableText>(find.byType(SelectableText));
      // Should be plain text (no highlight) since filePaths don't match
      expect(selectableText.textSpan!.toPlainText(), '太郎が走った。');
    });

    testWidgets('no highlights when no search match is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('scrolls to target line when search match is selected',
        (WidgetTester tester) async {
      final longText =
          List.generate(200, (i) => '行${i + 1}: テストテキスト').join('\n');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            fileContentProvider.overrideWith((ref) async => longText),
            selectedSearchMatchProvider.overrideWith(() {
              return SelectedSearchMatchNotifier();
            }),
            selectedFileProvider.overrideWith(() {
              return SelectedFileNotifier();
            }),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                  body: SizedBox(height: 400, child: TextViewerPanel()))),
        ),
      );
      await tester.pumpAndSettle();

      final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView));
      final controller = scrollView.controller;
      expect(controller, isNotNull);
      expect(controller!.offset, 0.0);

      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(name: 'file.txt', path: '/path/to/file.txt'),
          );
      container.read(selectedSearchMatchProvider.notifier).select(
            filePath: '/path/to/file.txt',
            lineNumber: 100,
            query: 'テスト',
          );
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0.0));
    });

    testWidgets('scroll updates when selecting different match in same file',
        (WidgetTester tester) async {
      final longText =
          List.generate(200, (i) => '行${i + 1}: テストテキスト').join('\n');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            fileContentProvider.overrideWith((ref) async => longText),
            selectedSearchMatchProvider.overrideWith(() {
              return SelectedSearchMatchNotifier();
            }),
            selectedFileProvider.overrideWith(() {
              return SelectedFileNotifier();
            }),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                  body: SizedBox(height: 400, child: TextViewerPanel()))),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);

      container.read(selectedFileProvider.notifier).selectFile(
            const FileEntry(name: 'file.txt', path: '/path/to/file.txt'),
          );
      container.read(selectedSearchMatchProvider.notifier).select(
            filePath: '/path/to/file.txt',
            lineNumber: 50,
            query: 'テスト',
          );
      await tester.pumpAndSettle();

      final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView));
      final firstOffset = scrollView.controller!.offset;

      container.read(selectedSearchMatchProvider.notifier).select(
            filePath: '/path/to/file.txt',
            lineNumber: 150,
            query: 'テスト',
          );
      await tester.pumpAndSettle();

      expect(scrollView.controller!.offset, greaterThan(firstOffset));
    });

    testWidgets(
        'vertical mode VerticalTextViewer has onSelectionChanged wired up',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
            displayModeProvider.overrideWith(() {
              final notifier = DisplayModeNotifier();
              return notifier;
            }),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      // Set display mode to vertical
      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      await container
          .read(displayModeProvider.notifier)
          .setMode(TextDisplayMode.vertical);
      await tester.pumpAndSettle();

      // VerticalTextViewer should be present with onSelectionChanged
      expect(find.byType(VerticalTextViewer), findsOneWidget);
      final viewer = tester.widget<VerticalTextViewer>(
        find.byType(VerticalTextViewer),
      );
      expect(viewer.onSelectionChanged, isNotNull);
    });
  });

  group('buildRubyTextSpans', () {
    test('returns plain text span when no query provided', () {
      final segments = [const PlainTextSegment('テスト文章です')];
      final span = buildRubyTextSpans(segments, const TextStyle(), null);

      expect(span.children, hasLength(1));
      expect(span.children!.first.toPlainText(), 'テスト文章です');
    });

    test('highlights all occurrences of query in plain text', () {
      final segments = [
        const PlainTextSegment('太郎が走った。太郎が言った。'),
      ];
      final span =
          buildRubyTextSpans(segments, const TextStyle(), '太郎');

      expect(span.children, isNotNull);
      // Should contain highlighted and non-highlighted spans
      final plainTexts =
          span.children!.whereType<TextSpan>().toList();
      final highlighted = plainTexts
          .where((s) => s.style?.backgroundColor != null)
          .toList();
      expect(highlighted, hasLength(2));
      expect(highlighted[0].text, '太郎');
      expect(highlighted[1].text, '太郎');
    });

    test('highlight spans have background color', () {
      final segments = [const PlainTextSegment('太郎が走った')];
      final span =
          buildRubyTextSpans(segments, const TextStyle(), '太郎');

      final highlighted = span.children!
          .whereType<TextSpan>()
          .where((s) => s.style?.backgroundColor != null)
          .toList();
      expect(highlighted, hasLength(1));
    });

    test('is case-insensitive for ASCII', () {
      final segments = [const PlainTextSegment('Hello world HELLO')];
      final span =
          buildRubyTextSpans(segments, const TextStyle(), 'hello');

      expect(span.children, isNotNull);
      final highlightedParts = span.children!
          .whereType<TextSpan>()
          .where((s) => s.style?.backgroundColor != null)
          .toList();
      expect(highlightedParts, hasLength(2));
    });

    test('returns plain text when query not found', () {
      final segments = [const PlainTextSegment('テスト文章です')];
      final span =
          buildRubyTextSpans(segments, const TextStyle(), '存在しない');

      expect(span.toPlainText(), 'テスト文章です');
    });
  });

  group('Bookmark indicators in text viewer', () {
    testWidgets('shows bookmark icon on bookmarked line in horizontal mode',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final longText =
          List.generate(20, (i) => '行${i + 1}: テストテキスト').join('\n');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            fileContentProvider.overrideWith((ref) async => longText),
            bookmarkLineNumbersForFileProvider
                .overrideWithValue(const AsyncValue.data([5, 10])),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark), findsNWidgets(2));
    });

    testWidgets('shows no bookmark icons when no bookmarks exist',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
            bookmarkLineNumbersForFileProvider
                .overrideWithValue(const AsyncValue.data([])),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark), findsNothing);
    });
  });
}
