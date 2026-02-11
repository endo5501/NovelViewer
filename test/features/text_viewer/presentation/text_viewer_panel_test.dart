import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';

void main() {
  group('TextViewerPanel', () {
    testWidgets('shows placeholder when no file is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: TextViewerPanel())),
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
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
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
            fileContentProvider.overrideWith((ref) async => longText),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('text is selectable', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
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
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
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
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
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
            fileContentProvider
                .overrideWith((ref) async => '太郎が走った。'),
            selectedSearchMatchProvider.overrideWith(() {
              return SelectedSearchMatchNotifier();
            }),
            selectedFileProvider.overrideWith(() {
              return SelectedFileNotifier();
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
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
      // Should be plain text (no children spans) since filePaths don't match
      expect(selectableText.textSpan!.text, '太郎が走った。');
    });

    testWidgets('no highlights when no search match is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
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
            fileContentProvider.overrideWith((ref) async => longText),
            selectedSearchMatchProvider.overrideWith(() {
              return SelectedSearchMatchNotifier();
            }),
            selectedFileProvider.overrideWith(() {
              return SelectedFileNotifier();
            }),
          ],
          child: const MaterialApp(
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
            fileContentProvider.overrideWith((ref) async => longText),
            selectedSearchMatchProvider.overrideWith(() {
              return SelectedSearchMatchNotifier();
            }),
            selectedFileProvider.overrideWith(() {
              return SelectedFileNotifier();
            }),
          ],
          child: const MaterialApp(
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
  });

  group('buildHighlightedTextSpan', () {
    test('returns single span when no query provided', () {
      final span = buildHighlightedTextSpan(
        'テスト文章です',
        null,
        const TextStyle(),
      );

      expect(span.children, isNull);
      expect(span.text, 'テスト文章です');
    });

    test('highlights all occurrences of query', () {
      final span = buildHighlightedTextSpan(
        '太郎が走った。太郎が言った。',
        '太郎',
        const TextStyle(),
      );

      expect(span.children, isNotNull);
      expect(span.children!, hasLength(5));
      expect(span.children![0].toPlainText(), '');
      expect(span.children![1].toPlainText(), '太郎');
      expect(span.children![2].toPlainText(), 'が走った。');
      expect(span.children![3].toPlainText(), '太郎');
      expect(span.children![4].toPlainText(), 'が言った。');
    });

    test('highlight spans have background color', () {
      final span = buildHighlightedTextSpan(
        '太郎が走った',
        '太郎',
        const TextStyle(),
      );

      final highlightSpan = span.children![1] as TextSpan;
      expect(highlightSpan.style?.backgroundColor, isNotNull);
    });

    test('is case-insensitive for ASCII', () {
      final span = buildHighlightedTextSpan(
        'Hello world HELLO',
        'hello',
        const TextStyle(),
      );

      expect(span.children, isNotNull);
      final highlightedParts = span.children!
          .whereType<TextSpan>()
          .where((s) => s.style?.backgroundColor != null)
          .toList();
      expect(highlightedParts, hasLength(2));
    });

    test('returns plain text when query not found', () {
      final span = buildHighlightedTextSpan(
        'テスト文章です',
        '存在しない',
        const TextStyle(),
      );

      expect(span.text, 'テスト文章です');
      expect(span.children, isNull);
    });
  });
}
